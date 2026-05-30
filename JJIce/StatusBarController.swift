//
//  StatusBarController.swift
//  JJIce
//

import AppKit
import OSLog
import ServiceManagement

/// 经典折叠式菜单栏图标管理（竖线 + 箭头, 无私有 API）。
///
/// 菜单栏放两个状态项:
/// - `separatorItem`（分界竖线）: 既是隐藏边界的可见参照, 也是折叠的执行项。折叠时把 `length` 撑到比屏幕
///   还宽, 凭借菜单栏「从右向左排列、空间不足则左侧溢出屏外」的规则把**它左侧**的图标顶出可视区即完成隐藏,
///   同时把竖线自身 alpha 置 0（此时它已宽达整条栏）; 展开时恢复窄宽与显示。
/// - `toggleItem`（箭头）: 始终可见。左键切换折叠/展开, 右键（或 Ctrl+左键）弹菜单;
///   展开态显示 `chevron.left`, 折叠态 `chevron.right`。
///
/// 撑大的项自身会被挤出可见区, 故折叠职责由竖线承担、箭头只当常驻按钮——二者分离, 箭头才不会随之消失。
///
/// 布局（左→右）: `[可隐藏图标] [separator 竖线] [toggle 箭头] [常驻图标] [系统图标]`。
/// 用户按住 ⌘ 在菜单栏把图标拖到竖线左侧, 即把其纳入折叠范围。
@MainActor
final class StatusBarController {
    private let separatorItem: NSStatusItem
    private let toggleItem: NSStatusItem

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "JJIce", category: "StatusBar")

    private static let collapsedDefaultsKey = "JJIce.isCollapsed"
    private static let didApplyDefaultLaunchAtLoginKey = "JJIce.didApplyDefaultLaunchAtLogin"
    private static let repositoryURL = URL(string: "https://github.com/yigegongjiang/JJIce")!

    /// 是否折叠（左侧图标已收起）。写入即持久化并刷新两个状态项。
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

        // 先建 toggle、后建 separator: 无位置记忆时新项落在已有项左侧,
        // 从而保证 separator 位于 toggle 左边, 契合 [图标][separator][toggle] 布局。
        let statusBar = NSStatusBar.system
        self.toggleItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.separatorItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        configureSeparatorItem()
        configureToggleItem()
        applyCollapsedState()
        enableLaunchAtLoginByDefaultIfNeeded()
    }

    // MARK: - 配置

    private func configureSeparatorItem() {
        separatorItem.autosaveName = "JJIce.Separator"
        guard let button = separatorItem.button else { return }
        button.image = makeSeparatorImage()
        button.toolTip = "JJIce 分界线 · 左侧图标会被折叠隐藏"
    }

    private func configureToggleItem() {
        toggleItem.autosaveName = "JJIce.Toggle"
        guard let button = toggleItem.button else { return }
        button.target = self
        button.action = #selector(handleToggleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// 绘制一条居中细竖线作为分界标识; template 图以自动适配深/浅色菜单栏。
    private func makeSeparatorImage() -> NSImage {
        let size = NSSize(width: 7, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        let lineWidth: CGFloat = 1
        NSRect(x: (size.width - lineWidth) / 2, y: 3, width: lineWidth, height: size.height - 6).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - 折叠状态

    /// 折叠时撑开的宽度: 取最宽屏 + 余量, 确保把左侧所有图标顶出屏外（含超宽屏）。
    private var expandedLength: CGFloat {
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 0
        return max(10_000, widestScreen + 200)
    }

    private func applyCollapsedState() {
        if isCollapsed {
            // 撑大分界项顶出其左侧图标, 并隐藏竖线本身（此时它已宽达整条菜单栏）。
            separatorItem.length = expandedLength
            separatorItem.button?.alphaValue = 0
        } else {
            separatorItem.length = NSStatusItem.variableLength
            separatorItem.button?.alphaValue = 1
        }

        // 箭头方向 = 下一步动作: 展开态指左（可折叠）, 折叠态指右（可展开）。
        let symbolName = isCollapsed ? "chevron.right" : "chevron.left"
        let description = isCollapsed ? "展开被隐藏的菜单栏图标" : "折叠并隐藏左侧菜单栏图标"
        toggleItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        toggleItem.button?.toolTip = description
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
        let origin = NSPoint(x: 0, y: button.bounds.height + 4)
        makeMenu().popUp(positioning: nil, at: origin, in: button)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

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

        let helpItem = NSMenuItem(title: "帮助", action: #selector(menuOpenHelp), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)

        let quitItem = NSMenuItem(title: "退出 JJIce", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func menuOpenHelp() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    @objc private func menuShowAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = "JJIce \(version)"
        alert.informativeText = "菜单栏图标管理工具。\n点箭头折叠/展开; 按住 ⌘ 把图标拖到分界竖线左侧即纳入隐藏。"
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

    /// 首次启动默认开启开机自启（仅一次, 记标志位）。此后用户在菜单里的开/关被尊重, 不再覆盖。
    private func enableLaunchAtLoginByDefaultIfNeeded() {
        guard !defaults.bool(forKey: Self.didApplyDefaultLaunchAtLoginKey) else { return }
        defaults.set(true, forKey: Self.didApplyDefaultLaunchAtLoginKey)

        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            logger.error("默认开机自启注册失败: \(error.localizedDescription, privacy: .public)")
        }
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
