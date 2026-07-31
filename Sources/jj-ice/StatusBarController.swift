//
//  StatusBarController.swift
//  jj-ice
//

import AppKit
import OSLog
import ServiceManagement

/// Classic divider + toggle menu bar item layout, implemented without private APIs.
/// Left to right: `[hideable items] [divider] [toggle] [speed] [pinned items] [system items]`.
@MainActor
final class StatusBarController {
    private let separatorItem: NSStatusItem
    private let toggleItem: NSStatusItem
    private let netSpeedItem: NSStatusItem

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "jj-ice", category: "StatusBar")

    private let speedMonitor = NetworkSpeedMonitor()
    private var speedTask: Task<Void, Never>?

    private static let collapsedDefaultsKey = "jj-ice.isCollapsed"
    private static let netSpeedVisibleDefaultsKey = "jj-ice.showNetworkSpeed"
    private static let didApplyDefaultLaunchAtLoginKey = "jj-ice.didApplyDefaultLaunchAtLogin"
    private static let netSpeedAutosaveName = "jj-ice.NetSpeed"
    private static let repositoryURL = URL(string: "https://github.com/yigegongjiang/jj-ice")!

    private var isCollapsed: Bool {
        didSet {
            guard isCollapsed != oldValue else { return }
            defaults.set(isCollapsed, forKey: Self.collapsedDefaultsKey)
            applyCollapsedState()
        }
    }

    private var isNetSpeedVisible: Bool {
        didSet {
            guard isNetSpeedVisible != oldValue else { return }
            defaults.set(isNetSpeedVisible, forKey: Self.netSpeedVisibleDefaultsKey)
            applyNetSpeedVisibility()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isCollapsed = defaults.bool(forKey: Self.collapsedDefaultsKey)
        defaults.register(defaults: [Self.netSpeedVisibleDefaultsKey: true])
        self.isNetSpeedVisible = defaults.bool(forKey: Self.netSpeedVisibleDefaultsKey)

        // Without a saved position, newer status items appear to the left, so create right to
        // left: speed, toggle, divider. The speed readout must end up right of the divider,
        // otherwise collapsing would hide the thing the user wants to watch.
        let statusBar = NSStatusBar.system
        Self.seedNetSpeedPosition(defaults)
        self.netSpeedItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.toggleItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.separatorItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        configureSeparatorItem()
        configureToggleItem()
        configureNetSpeedItem()
        applyCollapsedState()
        applyNetSpeedVisibility()
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

    private func configureNetSpeedItem() {
        netSpeedItem.autosaveName = Self.netSpeedAutosaveName
        guard let button = netSpeedItem.button else { return }
        button.target = self
        button.action = #selector(handleNetSpeedClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = makeSpeedImage(for: nil)
        button.toolTip = "Upload / download rate of the physical network links"
    }

    /// AppKit keeps each item's slot in `NSStatusItem Preferred Position <autosaveName>`, a
    /// distance from the right edge where smaller means further right. On the launch that first
    /// creates the speed item it has no slot yet and can land left of the divider - exactly where
    /// collapsing hides it. Seeding 0 asks for the rightmost slot available to a third-party item;
    /// AppKit clamps it into the usable range and owns the value from then on.
    private static func seedNetSpeedPosition(_ defaults: UserDefaults) {
        let key = "NSStatusItem Preferred Position \(netSpeedAutosaveName)"
        guard defaults.object(forKey: key) == nil else { return }
        defaults.set(0, forKey: key)
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

    // MARK: - Network Speed

    private func applyNetSpeedVisibility() {
        netSpeedItem.isVisible = isNetSpeedVisible
        if isNetSpeedVisible {
            startSpeedUpdates()
        } else {
            stopSpeedUpdates()
        }
    }

    private func startSpeedUpdates() {
        guard speedTask == nil else { return }
        speedMonitor.reset()
        netSpeedItem.button?.image = makeSpeedImage(for: nil)
        speedTask = Task { [weak self] in
            // One tick per second. The rate itself is derived from the measured elapsed time,
            // so timer drift, coalescing and sleep/wake cannot distort it.
            while !Task.isCancelled {
                guard let self else { return }
                if let speed = self.speedMonitor.sample() {
                    self.netSpeedItem.button?.image = self.makeSpeedImage(for: speed)
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopSpeedUpdates() {
        speedTask?.cancel()
        speedTask = nil
    }

    /// Two stacked monospaced lines drawn into a single template image: the system re-tints
    /// template images, so the readout follows light and dark menu bars plus accessibility
    /// tints for free. Nil renders the idle placeholder shown before the first rate exists.
    private func makeSpeedImage(for speed: NetworkSpeed?) -> NSImage {
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: NSColor.black,  // template image: only coverage matters, not the color
        ]
        let lines = [
            NSAttributedString(string: "↑ " + Self.format(speed?.uploadBytesPerSecond), attributes: attributes),
            NSAttributedString(string: "↓ " + Self.format(speed?.downloadBytesPerSecond), attributes: attributes),
        ]

        // Both lines must fit the menu bar, so cap the line height rather than trust the font metrics.
        let lineHeight = min((font.ascender - font.descender).rounded(.up),
                             ((NSStatusBar.system.thickness - 2) / 2).rounded(.down))
        let width = max(1, lines.map { $0.size().width }.max()?.rounded(.up) ?? 1)
        let image = NSImage(size: NSSize(width: width, height: lineHeight * 2))
        image.lockFocus()
        lines[0].draw(in: NSRect(x: 0, y: lineHeight, width: width, height: lineHeight))
        lines[1].draw(in: NSRect(x: 0, y: 0, width: width, height: lineHeight))
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Fixed eight-character field so the item keeps a constant width instead of jittering with
    /// every reading: `  0 KB/s`, ` 12 KB/s`, `1.2 MB/s`, ` 12 MB/s`. Units are binary (1 KB = 1024 B).
    private static func format(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "  0 KB/s" }
        let kilobytes = bytesPerSecond / 1024
        if kilobytes < 999.5 { return String(format: "%3.0f KB/s", kilobytes) }
        let megabytes = kilobytes / 1024
        if megabytes < 9.95 { return String(format: "%3.1f MB/s", megabytes) }
        if megabytes < 999.5 { return String(format: "%3.0f MB/s", megabytes) }
        return String(format: "%3.1f GB/s", megabytes / 1024)
    }

    // MARK: - Interaction

    @objc private func handleToggleClick() {
        // Right click and Control-click open the menu; other clicks toggle collapse.
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            presentMenu(on: toggleItem)
        } else {
            isCollapsed.toggle()
        }
    }

    /// The speed readout has nothing to toggle, so any click opens the menu - which is also the
    /// only way back after hiding it.
    @objc private func handleNetSpeedClick() {
        presentMenu(on: netSpeedItem)
    }

    private func presentMenu(on item: NSStatusItem) {
        guard let button = item.button else { return }
        item.menu = makeMenu()
        defer { item.menu = nil }
        button.performClick(nil)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let speedItem = makeMenuItem(title: "Show Network Speed", action: #selector(menuToggleNetSpeed))
        speedItem.state = isNetSpeedVisible ? .on : .off
        menu.addItem(speedItem)

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

    @objc private func menuToggleNetSpeed() {
        isNetSpeedVisible.toggle()
    }

    @objc private func menuOpenHelp() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    @objc private func menuShowAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = "jj-ice \(version)"
        alert.informativeText = """
        Menu bar item organizer with a network speed readout.
        Click the arrow to collapse or expand; hold Command and drag items to the left side of the divider to hide them.
        The speed readout sums the physical links, so a VPN going up or down does not change the numbers.
        """
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

        guard SMAppService.mainApp.status != .enabled else {
            defaults.set(true, forKey: Self.didApplyDefaultLaunchAtLoginKey)
            return
        }
        do {
            try SMAppService.mainApp.register()
            // Record the applied default only on success: a failed registration (an unsigned
            // bundle used to be one) must be retried next launch, not silently made permanent.
            defaults.set(true, forKey: Self.didApplyDefaultLaunchAtLoginKey)
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
