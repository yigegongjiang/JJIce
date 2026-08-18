//
//  BatteryNotifier.swift
//  jj-ice
//

import Foundation
import OSLog

/// Calls the user's endpoint every time the battery drops another percent below their threshold.
///
/// Step triggered and persistent: 30, 29, 28 ... 1 each send once, a level already sent never
/// repeats, and the last notified level outlives relaunches so restarting the app cannot re-send
/// it. Charging back above the threshold clears it, which starts the descent over. With no rule
/// stored, notifications are simply off.
final class BatteryNotifier {
    private static let ruleKey = "jj-ice.airPodsNotifyRule"

    /// Lowest level already sent, or absent while none has been. Written only after a request
    /// succeeds, so a failed one is retried rather than skipped.
    private static let lastSentKey = "jj-ice.airPodsNotifyLastSent"

    /// Written by versions up to 0.8.0. Cleared on launch so a stale flag cannot linger in the
    /// user's defaults forever.
    private static let legacyFiredKey = "jj-ice.airPodsNotifyFired"

    /// A refused request is retried on the next poll, but only a few times: an endpoint that is
    /// permanently broken must not become one request every 15 s for as long as the app runs.
    /// Counted per level, so a bad endpoint costs at most three requests per percent.
    private static let maxAttempts = 3

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "jj-ice", category: "Notify")

    /// Parsed once at load and at every save, never per sample: a rule that somehow fails to parse
    /// would otherwise log the same complaint every 15 s forever.
    private var rule: BatteryNotifyRule?

    /// The level `attempts` belongs to; a different level starts its own count.
    private var attemptedPercent: Int?
    private var attempts = 0
    private var isSending = false

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.rule = defaults.string(forKey: Self.ruleKey).flatMap { try? BatteryNotifyRule.parse($0) }
        defaults.removeObject(forKey: Self.legacyFiredKey)
    }

    /// What the editor opens with: the saved rule, or the template on a first visit.
    var editorText: String {
        defaults.string(forKey: Self.ruleKey) ?? BatteryNotifyRule.template
    }

    /// Validate and store. Blank text turns notifications off and brings the template back on the
    /// next open. Saving always re-arms, so a corrected rule fires on the next sample below the
    /// threshold instead of waiting for a recharge.
    func save(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: Self.ruleKey)
            rule = nil
        } else {
            rule = try BatteryNotifyRule.parse(trimmed)
            defaults.set(trimmed, forKey: Self.ruleKey)
        }
        rearm()
    }

    /// Feed every sample here; nil means nothing is connected, which neither sends nor re-arms -
    /// taking the AirPods out and putting them back must not repeat a notification.
    func handle(percent: Int?) {
        guard let percent, let rule else { return }
        guard percent <= rule.threshold else {
            // Charged back above the line, so the descent starts over.
            rearm()
            return
        }
        // Strictly lower only: a level already sent never repeats, and the percent wobbling back up
        // a point without leaving the threshold is not a new drop.
        if let sent = defaults.object(forKey: Self.lastSentKey) as? Int, percent >= sent { return }
        if attemptedPercent != percent {
            attemptedPercent = percent
            attempts = 0
        }
        guard attempts < Self.maxAttempts, !isSending else { return }

        attempts += 1
        let request: URLRequest
        do {
            request = try rule.makeRequest(percent: percent)
        } catch {
            // Stored rules are validated on save, so this needs a hand-edited defaults entry.
            // Retrying cannot help: stop until the user saves again.
            logger.error("Battery notification request could not be built; giving up until the rule changes.")
            attempts = Self.maxAttempts
            return
        }

        isSending = true
        Task { [weak self] in
            let result = await Self.send(request)
            guard let self else { return }
            isSending = false
            if result.ok {
                defaults.set(percent, forKey: Self.lastSentKey)
            } else {
                // The level is left unrecorded on purpose: the next poll retries, up to
                // `maxAttempts`, and a further drop retries at the new level.
                logger.error("""
                Battery notification to \(rule.host, privacy: .public) failed \
                (attempt \(self.attempts, privacy: .public)/\(Self.maxAttempts, privacy: .public)): \
                \(result.message, privacy: .public)
                """)
            }
        }
    }

    /// Send now, ignoring the threshold and the levels already sent, and describe what happened. The
    /// dialog's test button lands here so a test exercises the same request builder and the same
    /// transport as a real notification - anything else would prove nothing.
    func test(text: String, percent: Int?) async -> (ok: Bool, message: String) {
        do {
            let rule = try BatteryNotifyRule.parse(text)
            // Without a connected accessory there is no level to report, so stand in the threshold -
            // the number the notification would have carried.
            let request = try rule.makeRequest(percent: percent ?? rule.threshold)
            return await Self.send(request)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Internals

    private func rearm() {
        attempts = 0
        attemptedPercent = nil
        // Only write when there is something to clear: this runs on every sample above the
        // threshold.
        if defaults.object(forKey: Self.lastSentKey) != nil {
            defaults.removeObject(forKey: Self.lastSentKey)
        }
    }

    /// The single transport for both paths. Never logs or returns the url or the headers - a header
    /// can hold a token.
    private static func send(_ request: URLRequest) async -> (ok: Bool, message: String) {
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode else {
                return (false, "The endpoint gave a reply that is not HTTP.")
            }
            let ok = (200..<300).contains(status)
            return (ok, ok ? "The endpoint answered HTTP \(status)." : "The endpoint refused it: HTTP \(status).")
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
