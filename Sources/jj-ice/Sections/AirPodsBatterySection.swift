//
//  AirPodsBatterySection.swift
//  jj-ice
//

import AppKit

/// Battery percentage of the connected AirPods, shown as an icon plus `79%`.
///
/// Display only: no click action, and it removes itself whenever no audio accessory is connected,
/// so there is nothing for the user to configure and nothing to hide.
final class AirPodsBatterySection: StatusSection {
    /// The level only moves a percent every few minutes, and connect/disconnect shows up as the
    /// reading appearing or vanishing rather than as a separate event. 15 s makes a freshly worn
    /// pair visible almost at once while costing ~60 ms of CPU per tick.
    override var refreshInterval: Duration { .seconds(15) }

    init(defaults: UserDefaults) {
        super.init(
            autosaveName: "jj-ice.AirPodsBattery",
            visibilityDefaultsKey: nil,
            defaults: defaults
        )
        // Deliberately left visible until the first sample decides: hiding the item inside `init`
        // makes AppKit drop its `NSStatusItem Preferred Position` entry (measured), which gives up
        // the seeded rightmost slot and lets the readout reappear left of the divider. The cost is
        // an icon with no percentage for as long as the first read takes, about 60 ms.
        guard let button = item.button else { return }
        // No target or action on purpose: clicking must not open anything.
        button.image = NSImage(systemSymbolName: "airpods", accessibilityDescription: "AirPods battery")
        button.imagePosition = .imageLeading
        button.toolTip = "AirPods battery - one earbud; the pair drains together"
    }

    override func refresh() async -> Bool {
        // ~60 ms of subprocess would hitch the menu bar if it ran on the main thread.
        let percent = await Task.detached { AirPodsBatteryMonitor.read() }.value
        item.button?.title = percent.map { "\($0)%" } ?? ""
        return percent != nil
    }
}
