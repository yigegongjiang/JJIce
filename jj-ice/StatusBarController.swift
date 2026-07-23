//
//  StatusBarController.swift
//  jj-ice
//

import AppKit
import OSLog
import ServiceManagement

/// Classic divider + toggle menu bar item layout, implemented without private APIs.
/// Left to right: `[hideable items] [divider] [toggle] [pinned items] [system items]`.
@MainActor
final class StatusBarController {
    private let separatorItem: NSStatusItem
    private let toggleItem: NSStatusItem

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "jj-ice", category: "StatusBar")

    private static let collapsedDefaultsKey = "jj-ice.isCollapsed"
    private static let didApplyDefaultLaunchAtLoginKey = "jj-ice.didApplyDefaultLaunchAtLogin"
    private static let repositoryURL = URL(string: "https://github.com/yigegongjiang/jj-ice")!

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

        // Create toggle first: without a saved position, newer status items appear to the left.
        let statusBar = NSStatusBar.system
        self.toggleItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.separatorItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        configureSeparatorItem()
        configureToggleItem()
        applyCollapsedState()
        enableLaunchAtLoginByDefaultIfNeeded()
    }

    // MARK: - Setup

    private func configureSeparatorItem() {
        separatorItem.autosaveName = "jj-ice.Separator"
        guard let button = separatorItem.button else { return }
        button.image = makeSeparatorImage()
        button.toolTip = "jj-ice divider - items on the left are hidden when collapsed"
    }

    private func configureToggleItem() {
        toggleItem.autosaveName = "jj-ice.Toggle"
        guard let button = toggleItem.button else { return }
        button.target = self
        button.action = #selector(handleToggleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Draw a centered divider line. Template images adapt to light and dark menu bars.
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

    // MARK: - Collapse State

    /// Use the widest display plus margin so collapsed items are pushed off screen.
    private var expandedLength: CGFloat {
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 0
        return max(10_000, widestScreen + 200)
    }

    private func applyCollapsedState() {
        if isCollapsed {
            // Widen the divider to push left-side items away, then hide the divider itself.
            separatorItem.length = expandedLength
            separatorItem.button?.alphaValue = 0
        } else {
            separatorItem.length = NSStatusItem.variableLength
            separatorItem.button?.alphaValue = 1
        }

        // Arrow direction describes the next action.
        let symbolName = isCollapsed ? "chevron.right" : "chevron.left"
        let description = isCollapsed ? "Show hidden menu bar items" : "Hide menu bar items on the left"
        toggleItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        toggleItem.button?.toolTip = description
    }

    // MARK: - Interaction

    @objc private func handleToggleClick() {
        // Right click and Control-click open the menu; other clicks toggle collapse.
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            presentMenu()
        } else {
            isCollapsed.toggle()
        }
    }

    private func presentMenu() {
        guard let button = toggleItem.button else { return }
        toggleItem.menu = makeMenu()
        defer { toggleItem.menu = nil }
        button.performClick(nil)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let launchItem = makeMenuItem(title: "Launch at Login", action: #selector(menuToggleLaunchAtLogin))
        launchItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        menu.addItem(makeMenuItem(title: "Help", action: #selector(menuOpenHelp)))
        menu.addItem(makeMenuItem(title: "About", action: #selector(menuShowAbout)))
        menu.addItem(makeMenuItem(title: "Quit jj-ice", action: #selector(menuQuit), keyEquivalent: "q"))

        return menu
    }

    private func makeMenuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func menuOpenHelp() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    @objc private func menuShowAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = "jj-ice \(version)"
        alert.informativeText = "Menu bar item organizer.\nClick the arrow to collapse or expand; hold Command and drag items to the left side of the divider to hide them."
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    // MARK: - Launch at Login

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Enable Launch at Login once on first launch, then respect the user's menu choice.
    private func enableLaunchAtLoginByDefaultIfNeeded() {
        guard !defaults.bool(forKey: Self.didApplyDefaultLaunchAtLoginKey) else { return }
        defaults.set(true, forKey: Self.didApplyDefaultLaunchAtLoginKey)

        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            logger.error("Default Launch at Login registration failed: \(error.localizedDescription, privacy: .public)")
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
            logger.error("Launch at Login toggle failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Unable to Change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            NSApp.activate()
            alert.runModal()
        }
    }
}
