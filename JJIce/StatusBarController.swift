//
//  StatusBarController.swift
//  JJIce
//

import AppKit
import OSLog
import ServiceManagement

/// 经典折叠式菜单栏图标管理（无私有 API）。
///
/// 原理：在菜单栏放两个状态项——
/// - `separatorItem`（分界竖线）：折叠时把 `length` 撑到比屏幕还宽，凭借菜单栏
///   「从右向左排列、空间不足则左侧溢出屏外」的规则，把**它左侧**的所有图标顶出可视区，
///   即完成隐藏；展开时恢复窄宽，图标回归。
/// - `toggleItem`（开关）：始终可见。左键切换折叠/展开，右键（或 Ctrl+左键）弹出菜单。
///
/// 布局（左→右）：`[可隐藏图标] [separator] [toggle] [常驻图标] [系统图标]`。
/// 用户按住 ⌘ 在菜单栏把图标拖到分界竖线左侧，即把其纳入折叠范围（macOS 原生交互，一次性设定）。
@MainActor
final class StatusBarController {
    private let separatorItem: NSStatusItem
    private let toggleItem: NSStatusItem

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "JJIce", category: "StatusBar")

    private static let collapsedDefaultsKey = "JJIce.isCollapsed"

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

        // 先建 toggle、后建 separator：无位置记忆时新项落在已有项左侧，
        // 从而保证 separator 位于 toggle 左边，契合 [图标][separator][toggle] 布局。
        let statusBar = NSStatusBar.system
        self.toggleItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.separatorItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        configureSeparatorItem()
        configureToggleItem()
        applyCollapsedState()
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

    /// 绘制一条居中细竖线作为分界标识；template 图以自动适配深/浅色菜单栏。
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

    /// 折叠时分界项需要的宽度：取最宽屏 + 余量，确保把左侧所有图标顶出屏外（含超宽屏）。
    private var expandedLength: CGFloat {
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 0
        return max(10_000, widestScreen + 200)
    }

    private func applyCollapsedState() {
        if isCollapsed {
            // 撑大分界项顶出其左侧图标，并隐藏竖线本身（此时它已宽达整条菜单栏）。
            separatorItem.length = expandedLength
            separatorItem.button?.alphaValue = 0
        } else {
            separatorItem.length = NSStatusItem.variableLength
            separatorItem.button?.alphaValue = 1
        }

        // 开关图标的箭头方向 = 下一步动作：展开态指左（可折叠），折叠态指右（可展开）。
        let symbolName = isCollapsed ? "chevron.right" : "chevron.left"
        let description = isCollapsed ? "展开被隐藏的菜单栏图标" : "折叠并隐藏左侧菜单栏图标"
        toggleItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
    }

    // MARK: - 交互

    @objc private func handleToggleClick() {
        // 右键 / Ctrl+左键 弹菜单，其余切换折叠。
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
        alert.informativeText = "菜单栏图标管理工具。\n点箭头折叠/展开；按住 ⌘ 把图标拖到分界线左侧即纳入隐藏。"
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
