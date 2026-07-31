//
//  NetworkSpeedMonitor.swift
//  jj-ice
//

import Darwin
import Foundation

/// Instantaneous throughput of the machine's physical links.
struct NetworkSpeed {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

/// Turns consecutive interface byte counters into a rate.
///
/// Counter source: `sysctl(CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, <if_index>, IFDATA_GENERAL)`
/// filling `struct ifmibdata`, whose `ifmd_data` is a 64-bit `if_data64`. Measured on macOS 26.5.2
/// with an ad-hoc signed binary: byte accurate and monotonic well past 4 GiB. Both obvious
/// alternatives are unusable for a third-party app:
/// - `NET_RT_IFLIST2`: the kernel quantises the counters it reports to binaries it did not sign
///   into 1 KiB steps, and wraps them at 4 GiB (measured: exactly 4294967296 below the MIB value).
/// - `getifaddrs`: only exposes the 32-bit `struct if_data`, which wraps every 4 GiB.
final class NetworkSpeedMonitor {
    private struct Counters {
        var input: UInt64
        var output: UInt64
    }

    /// Previous sample keyed by interface name, replaced wholesale on every sample so that
    /// interfaces coming and going (VPN, USB adapters) cannot accumulate entries.
    private var previous: [String: Counters] = [:]
    private var previousUptime: UInt64 = 0

    /// A longer gap is not a measurement: sleep/wake, timer coalescing under load or a paused
    /// process would otherwise average a burst away or invent one. Such a tick only re-arms
    /// the baseline.
    private static let maximumInterval: Double = 5

    /// Nil while no usable pair of samples exists yet, and on any tick whose elapsed time
    /// cannot be trusted.
    func sample() -> NetworkSpeed? {
        // CLOCK_UPTIME_RAW: monotonic, immune to clock adjustments, frozen while the machine sleeps.
        let uptime = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let current = readCounters()
        let baseline = previous
        let baselineUptime = previousUptime
        let elapsed = Double(uptime &- baselineUptime) / 1_000_000_000

        previous = current
        previousUptime = uptime

        // baselineUptime == 0 means this is the first sample, so there is nothing to diff against.
        guard baselineUptime != 0, elapsed > 0, elapsed <= Self.maximumInterval else { return nil }

        var input: UInt64 = 0
        var output: UInt64 = 0
        for (name, counters) in current {
            guard let old = baseline[name] else { continue }  // first sight of this link: baseline only
            // A re-created interface restarts from 0 (Wi-Fi reconnect, USB adapter replug, VPN
            // client reinstalling its device). Drop that step instead of underflowing.
            if counters.input >= old.input { input += counters.input - old.input }
            if counters.output >= old.output { output += counters.output - old.output }
        }

        return NetworkSpeed(downloadBytesPerSecond: Double(input) / elapsed,
                            uploadBytesPerSecond: Double(output) / elapsed)
    }

    /// Drop the baseline so the next sample only re-arms it. Used when monitoring resumes.
    func reset() {
        previous = [:]
        previousUptime = 0
    }

    // MARK: - Interface MIB

    private func readCounters() -> [String: Counters] {
        var result: [String: Counters] = [:]
        guard let rows = interfaceCount() else { return result }

        for row in 1...rows {
            var mib: [CInt] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, row, IFDATA_GENERAL]
            var data = ifmibdata()
            var size = MemoryLayout<ifmibdata>.size
            // Rows are if_index values: indices freed by removed interfaces answer ENOENT.
            guard sysctl(&mib, UInt32(mib.count), &data, &size, nil, 0) == 0 else { continue }
            guard data.ifmd_data.ifi_type == UInt8(IFT_ETHER) else { continue }

            let name = withUnsafeBytes(of: data.ifmd_name) { bytes in
                String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
            }
            guard Self.isPhysicalLink(name) else { continue }
            result[name] = Counters(input: data.ifmd_data.ifi_ibytes, output: data.ifmd_data.ifi_obytes)
        }
        return result
    }

    /// Highest assigned `if_index`; the MIB is walked from 1 to this value.
    private func interfaceCount() -> CInt? {
        var mib: [CInt] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT]
        var count: CInt = 0
        var size = MemoryLayout<CInt>.size
        guard sysctl(&mib, UInt32(mib.count), &count, &size, nil, 0) == 0, count > 0 else { return nil }
        return count
    }

    /// Physical uplinks only — `en0`, `en5`, … — which is what keeps the reading stable across
    /// VPN toggles. Tunnelled traffic is counted a second time on the physical link it leaves
    /// through, so summing tunnels as well would double count and make the numbers jump every
    /// time a tunnel appears or goes away. The `en<digits>` shape covers every real uplink macOS
    /// exposes (Wi-Fi, Ethernet, USB/Thunderbolt adapters, iPhone tethering) while excluding
    /// `utun`/`ipsec`/`ppp` (tunnels), `bridge`/`vmenet`/`feth` (virtual machines and bridges),
    /// `awdl`/`llw`/`ap`/`anpi` (AirDrop, Apple's internal radios and coprocessor links) and
    /// `lo`/`gif`/`stf`.
    private static func isPhysicalLink(_ name: String) -> Bool {
        guard name.hasPrefix("en") else { return false }
        let index = name.dropFirst(2)
        return !index.isEmpty && index.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
