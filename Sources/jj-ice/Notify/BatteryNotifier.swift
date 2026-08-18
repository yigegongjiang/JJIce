//
//  BatteryNotifier.swift
//  jj-ice
//

import Foundation
import OSLog

/// Calls the user's endpoint once the battery has dropped to their threshold.
///
/// Edge triggered and persistent: one request per crossing, re-armed only after the level climbs
/// back above the threshold, and the fired flag outlives relaunches so restarting the app cannot
/// re-notify. With no rule stored, notifications are simply off.
final class BatteryNotifier {
    private static let ruleKey = "jj-ice.airPodsNotifyRule"
    private static let firedKey = "jj-ice.airPodsNotifyFired"

    /// A refused request is retried on the next poll, but only a few times: an endpoint that is
    /// permanently broken must not become one request every 15 s for as long as the app runs.
    private static let maxAttempts = 3

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "jj-ice", category: "Notify")

    /// Parsed once at load and at every save, never per sample: a rule that somehow fails to parse
    /// would otherwise log the same complaint every 15 s forever.
    private var rule: BatteryNotifyRule?
    private var attempts = 0
    private var isSending = false

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.rule = defaults.string(forKey: Self.ruleKey).flatMap { try? BatteryNotifyRule.parse($0) }
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

    /// Feed every sample here; nil means nothing is connected, which neither fires nor re-arms -
    /// taking the AirPods out and putting them back must not repeat a notification.
    func handle(percent: Int?) {
        guard let percent, let rule else { return }
        guard percent <= rule.threshold else {
            // Charged back above the line, so the next crossing is a new event.
            rearm()
            return
        }
        guard !defaults.bool(forKey: Self.firedKey), attempts < Self.maxAttempts, !isSending else { return }

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
                defaults.set(true, forKey: Self.firedKey)
            } else {
                // Left un-fired on purpose: the next poll retries, up to `maxAttempts`.
                logger.error("""
                Battery notification to \(rule.host, privacy: .public) failed \
                (attempt \(self.attempts, privacy: .public)/\(Self.maxAttempts, privacy: .public)): \
                \(result.message, privacy: .public)
                """)
            }
        }
    }

    /// Send now, ignoring the threshold and the fired flag, and describe what happened. The dialog's
    /// test button lands here so a test exercises the same request builder and the same transport as
    /// a real notification - anything else would prove nothing.
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
        // Only write when it actually changes: this runs on every sample above the threshold.
        if defaults.bool(forKey: Self.firedKey) {
            defaults.set(false, forKey: Self.firedKey)
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
