//
//  AirPodsBatteryMonitor.swift
//  jj-ice
//

import Foundation

/// Battery percentage of the connected Apple audio device, taken from
/// `system_profiler SPBluetoothDataType -json`.
///
/// No public framework exposes a Bluetooth accessory's battery level. The two alternatives are
/// the private `IOBluetoothDevice` KVC keys (`BatteryPercentLeft`, `BatteryPercentCombined`, ...)
/// and decoding Apple's BLE continuity advertisements; both are undocumented, have moved between
/// releases, and the latter also needs Bluetooth permission. `system_profiler` is a shipped,
/// unprivileged, stable interface and one call costs ~60 ms (measured on macOS 26), which is
/// affordable at the poll interval this readout needs.
///
/// Only one earbud is reported: a pair drains closely enough together that a single number is
/// what a menu bar readout wants.
nonisolated enum AirPodsBatteryMonitor {
    private static let executable = URL(fileURLWithPath: "/usr/sbin/system_profiler")

    /// Whichever key exists first wins. A pair fills `Left`/`Right`; a single-driver device
    /// (AirPods Max, mono headsets) reports `Main` or `Single` instead.
    private static let batteryKeys = [
        "device_batteryLevelLeft",
        "device_batteryLevelRight",
        "device_batteryLevelMain",
        "device_batteryLevelSingle",
    ]

    /// Keyboards, mice and trackpads report battery too, so restrict to audio accessories.
    private static let audioMinorTypes: Set<String> = ["Headphones", "Headset"]

    /// Blocks for as long as the subprocess runs - never call this on the main thread.
    /// Returns nil when nothing is connected, or when the output cannot be read or parsed;
    /// the caller treats every nil the same way, by hiding the readout.
    static func read() -> Int? {
        guard let data = runSystemProfiler(),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return nil }

        for controller in controllers {
            // Disconnected accessories move to `device_not_connected` and lose their battery
            // keys, so reading only `device_connected` cannot surface a stale percentage.
            guard let connected = controller["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                // Each entry is a single-pair dictionary keyed by the device's display name.
                for device in entry.values {
                    guard let device = device as? [String: Any],
                          let minorType = device["device_minorType"] as? String,
                          audioMinorTypes.contains(minorType)
                    else { continue }
                    if let percent = batteryKeys.lazy.compactMap({ percent(device[$0]) }).first {
                        return percent
                    }
                }
            }
        }
        return nil
    }

    /// Levels arrive as strings like `"79%"`. Anything outside 0...100 is treated as garbage.
    private static func percent(_ value: Any?) -> Int? {
        guard let text = value as? String,
              let percent = Int(text.trimmingCharacters(in: CharacterSet(charactersIn: "% "))),
              (0...100).contains(percent)
        else { return nil }
        return percent
    }

    private static func runSystemProfiler() -> Data? {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["-json", "SPBluetoothDataType"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }

        // Reap on every exit path: an unreaped child would pile up as one zombie per poll.
        defer {
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
        }
        // system_profiler can wedge when the Bluetooth stack is unhealthy, and this call sits on
        // the section's only refresh task - a permanent block would freeze the readout forever.
        // Terminating collapses the pipe, so the read returns short and the caller sees nil.
        // `defer` unwinds last in first out, so the timer is cancelled before the reap.
        let watchdog = DispatchWorkItem { [process = ProcessBox(process)] in process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10), execute: watchdog)
        defer { watchdog.cancel() }

        return try? pipe.fileHandleForReading.readToEnd()
    }
}

/// `Process` is not `Sendable`, but `terminate()` on a live process is safe from another thread
/// and is all the watchdog ever calls.
nonisolated private final class ProcessBox: @unchecked Sendable {
    private let process: Process

    init(_ process: Process) {
        self.process = process
    }

    func terminate() {
        if process.isRunning { process.terminate() }
    }
}
