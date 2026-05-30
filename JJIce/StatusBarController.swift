//
//  StatusBarController.swift
//  JJIce
//

import AppKit
import OSLog
import ServiceManagement

/// 极简折叠式菜单栏图标管理（单状态项, 无私有 API）。
///
/// 只放一个状态项 `toggleItem`（箭头）, 它**既是分界、又是开关**:
/// - 展开态: 窄项, 显示 `chevron.left`; 左键点击即折叠, 右键（或 Ctrl+左键）弹菜单。
/// - 折叠态: 把自身 `length` 撑到比屏幕还宽, 凭借菜单栏「从右向左排列、空间不足则左侧溢出屏外」
///   的规则把**它左侧**的所有图标顶出可视区即完成隐藏。因状态项右边界固定、length 只向左生长,
///   箭头原地不动; 再把 `chevron.right` 画在与撑开宽度等宽的透明模板图**最右端**, 箭头便钉在
///   可见区右端始终可点, 点击即展开。
///
/// 布局（左→右）: `[可隐藏图标] [toggle 箭头] [常驻图标] [系统图标]`。
/// 箭头本身即分界: 左侧图标会被折叠, 右侧常驻。按住 ⌘ 在菜单栏把图标拖到箭头左/右侧即设定其归属。
@MainActor
final class StatusBarController {
    private let toggleItem: NSStatusItem

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "JJIce", category: "StatusBar")

    private static let collapsedDefaultsKey = "JJIce.isCollapsed"

    /// 是否折叠（左侧图标已收起）。写入即持久化并刷新状态项。
    private var isCollapsed: Bool {
        didSet {
            guard isCollapsed != oldValue else { return }
            defaults.set(isCollapsed, forKey: Self.collapsedDefaultsKey)
            applyCollapsedState()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isCollapsed = defaults.bool(forKey: Self.collapsedDefaultsKey)

        let statusBar = NSStatusBar.system
        self.toggleItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        configureToggleItem()
        applyCollapsedState()
    }

    // MARK: - 配置

    private func configureToggleItem() {
        toggleItem.autosaveName = "JJIce.Toggle"
        guard let button = toggleItem.button else { return }
        button.target = self
        button.action = #selector(handleToggleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imageScaling = .scaleNone   // 折叠态用超宽图把箭头钉到最右端, 禁止缩放
    }

    // MARK: - 折叠状态

    /// 折叠时撑开的宽度: 取最宽屏 + 余量, 确保把左侧所有图标顶出屏外（含超宽屏）。
    private var expandedLength: CGFloat {
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 0
        return max(10_000, widestScreen + 200)
    }

    private func applyCollapsedState() {
        guard let button = toggleItem.button else { return }
        if isCollapsed {
            // 撑大本项顶出其左侧图标; 箭头画在超宽透明图最右端, 留在可见区可点。
            let width = expandedLength
            toggleItem.length = width
            button.image = makeCollapsedArrowImage(width: width)
            button.toolTip = "展开被隐藏的菜单栏图标"
        } else {
            toggleItem.length = NSStatusItem.variableLength
            button.image = NSImage(systemSymbolName: "chevron.left",
                                   accessibilityDescription: "折叠并隐藏左侧菜单栏图标")
            button.toolTip = "折叠并隐藏左侧菜单栏图标"
        }
    }

    /// 折叠态箭头: 一张与撑开宽度等宽的透明模板图, `chevron.right` 贴最右端绘制。
    /// 因 `imageScaling = .scaleNone` 且图宽 = 按钮宽, 图右端即按钮右端 = 菜单栏可见区, 箭头始终可点。
    private func makeCollapsedArrowImage(width: CGFloat) -> NSImage {
        let height: CGFloat = 18
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let chevron = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "展开被隐藏的菜单栏图标")?
            .withSymbolConfiguration(config)
        let canvas = NSImage(size: NSSize(width: width, height: height))
        canvas.lockFocus()
        if let chevron {
            let cs = chevron.size
            chevron.draw(in: NSRect(x: width - cs.width - 8, y: (height - cs.height) / 2,
                                    width: cs.width, height: cs.height))
        }
        canvas.unlockFocus()
        canvas.isTemplate = true
        return canvas
    }

    // MARK: - 交互

    @objc private func handleToggleClick() {
        // 右键 / Ctrl+左键 弹菜单, 其余切换折叠。
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            presentMenu()
        } else {
            isCollapsed.toggle()
        }
    }

    private func presentMenu() {
        guard let button = toggleItem.button else { return }
        // 折叠态 button 超宽且左端在屏外, 菜单锚到右端可见的箭头处; 展开态锚左端。
        let x = isCollapsed ? max(0, button.bounds.width - 22) : 0
        let origin = NSPoint(x: x, y: button.bounds.height + 4)
        makeMenu().popUp(positioning: nil, at: origin, in: button)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let collapseMenuItem = NSMenuItem(
            title: isCollapsed ? "展开图标" : "折叠图标",
            action: #selector(menuToggleCollapsed),
            keyEquivalent: ""
        )
        collapseMenuItem.target = self
        menu.addItem(collapseMenuItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "开机时启动",
            action: #selector(menuToggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "关于 JJIce", action: #selector(menuShowAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "退出 JJIce", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func menuToggleCollapsed() {
        isCollapsed.toggle()
    }

    @objc private func menuShowAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = "JJIce \(version)"
        alert.informativeText = "菜单栏图标管理工具。\n点箭头折叠/展开; 按住 ⌘ 把图标拖到箭头左侧即纳入隐藏, 拖到右侧则常驻。"
        alert.addButton(withTitle: "好")
        NSApp.activate()
        alert.runModal()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    // MARK: - 开机自启（SMAppService）

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func menuToggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            logger.error("切换开机自启失败: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "无法更改开机启动设置"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "好")
            NSApp.activate()
            alert.runModal()
        }
    }
}
