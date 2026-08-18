//
//  StatusSection.swift
//  jj-ice
//

import AppKit

/// One self-contained readout on the menu bar - network speed, AirPods battery, and whatever
/// comes next.
///
/// The app is three layers:
/// - `Monitors/` reads a hardware value and knows nothing about AppKit.
/// - `Sections/` owns exactly one `NSStatusItem`: placement, refresh loop, visibility, drawing.
/// - `StatusBarController` only arranges sections around the divider and toggle, and aggregates
///   their menu entries.
///
/// Adding a readout therefore means one subclass overriding `refresh()`, plus one entry in the
/// controller's section list. Everything below is shared plumbing; subclasses override
/// `refresh()`, and optionally `refreshInterval`, `menuToggleTitle`, `opensMenuOnClick` and
/// `start()`.
class StatusSection {
    let item: NSStatusItem

    /// Title of the menu entry that shows and hides this section. Nil means the user gets no
    /// switch because visibility follows the data alone.
    var menuToggleTitle: String? { nil }

    /// Whether clicking the readout opens the shared menu. Sections the user can hide need it -
    /// the menu is the only way back - while self-hiding readouts stay inert on click.
    var opensMenuOnClick: Bool { false }

    /// How often `refresh()` runs.
    var refreshInterval: Duration { .seconds(1) }

    private let defaults: UserDefaults
    private let visibilityDefaultsKey: String?
    private var refreshTask: Task<Void, Never>?

    /// - Parameters:
    ///   - autosaveName: AppKit's key for this item's menu bar slot. Renaming it for an already
    ///     shipped section would reset every user's icon position, so treat published names as
    ///     frozen.
    ///   - visibilityDefaultsKey: where the user's show/hide choice is stored, defaulting to
    ///     shown. Nil for sections without a switch. Also frozen once shipped, for the same
    ///     reason.
    init(autosaveName: String, visibilityDefaultsKey: String?, defaults: UserDefaults) {
        self.defaults = defaults
        self.visibilityDefaultsKey = visibilityDefaultsKey
        if let visibilityDefaultsKey {
            defaults.register(defaults: [visibilityDefaultsKey: true])
        }
        Self.seedRightmostPosition(autosaveName, defaults)
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.item.autosaveName = autosaveName
    }

    /// Backed by `UserDefaults` rather than stored, so reading it during `init` cannot fire an
    /// observer that would touch a subclass before it is fully initialised. Always true for a
    /// section without a switch.
    final var isEnabled: Bool {
        get {
            guard let visibilityDefaultsKey else { return true }
            return defaults.bool(forKey: visibilityDefaultsKey)
        }
        set {
            guard let visibilityDefaultsKey, newValue != isEnabled else { return }
            defaults.set(newValue, forKey: visibilityDefaultsKey)
            applyEnabled()
        }
    }

    /// Bring the section in line with `isEnabled`. Call once after construction.
    final func activate() {
        applyEnabled()
    }

    // MARK: - Subclass Hooks

    /// Sample the data source and draw the result. Return false when there is nothing to show -
    /// no device connected, and so on - which hides the item until data comes back.
    func refresh() async -> Bool {
        true
    }

    /// Start the refresh loop. Override to reset state first, then call `super.start()`.
    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let hasData = await self.refresh()
                // `stop()` can land while `refresh()` is awaiting; without this the loop would
                // resurrect an item that was just hidden.
                guard !Task.isCancelled else { return }
                self.item.isVisible = self.isEnabled && hasData
                try? await Task.sleep(for: self.refreshInterval)
            }
        }
    }

    /// Stop the refresh loop. The item keeps whatever it last drew.
    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Internals

    private func applyEnabled() {
        if isEnabled {
            start()
        } else {
            stop()
            item.isVisible = false
        }
    }

    /// AppKit keeps each item's slot in `NSStatusItem Preferred Position <autosaveName>`, a
    /// distance from the right edge where smaller means further right. A section shipped in a
    /// later version has no slot yet and can land left of the divider - exactly where collapsing
    /// hides it. Seeding 0 asks for the rightmost slot available to a third-party item; AppKit
    /// clamps it into the usable range and owns the value from then on.
    private static func seedRightmostPosition(_ autosaveName: String, _ defaults: UserDefaults) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        guard defaults.object(forKey: key) == nil else { return }
        defaults.set(0, forKey: key)
    }
}
