//
//  BatteryNotifyRule.swift
//  jj-ice
//

import Foundation

/// The user's low battery notification, parsed from the JSON they edit in the readout's dialog.
///
/// Pure value type: it turns text into a validated rule and a rule into a `URLRequest`, and knows
/// nothing about AppKit or `UserDefaults`. The real notification and the dialog's test button both
/// build their request here, so a passing test means the saved rule works.
nonisolated struct BatteryNotifyRule {
    /// Notify once the level has dropped to this percent.
    let threshold: Int

    private let address: String
    private let method: String
    private let query: [String: String]
    private let headers: [String: String]
    private let body: String

    /// Prefilled in the editor as a starting point. It only takes effect once saved - an untouched
    /// template MUST NOT send anything, because the app has no business calling an endpoint the
    /// user never confirmed.
    static let template = """
    {
      "threshold": 20,
      "url": "https://jj-cloudflare.yigegongjiang.com/notify",
      "method": "GET",
      "query": {
        "text": "AirPods battery {percent}%"
      },
      "headers": {},
      "body": ""
    }
    """

    /// Replaced with the battery level in the url, every query value, every header value and the
    /// body.
    private static let placeholder = "{percent}"

    /// A body only travels with these; `URLSession` drops it on the others.
    private static let methodsWithBody: Set<String> = ["POST", "PUT", "PATCH"]
    private static let methods = methodsWithBody.union(["GET", "HEAD", "DELETE"])

    /// RFC 3986 unreserved set. Everything else in a query gets escaped by hand - see
    /// `makeRequest(percent:)`.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    /// Throws `BatteryNotifyError` with a message meant to be shown to the user as is.
    static func parse(_ text: String) throws -> BatteryNotifyRule {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw BatteryNotifyError("This is not a JSON object. Check the braces and commas.") }

        guard let threshold = (root["threshold"] as? NSNumber)?.intValue, (1...100).contains(threshold) else {
            throw BatteryNotifyError("\"threshold\" must be a whole number between 1 and 100.")
        }

        let address = ((root["url"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scheme = URLComponents(string: address)?.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              URLComponents(string: address)?.host?.isEmpty == false
        else { throw BatteryNotifyError("\"url\" must be a full http or https address.") }

        let method = ((root["method"] as? String) ?? "GET")
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard methods.contains(method) else {
            throw BatteryNotifyError("\"method\" must be one of \(methods.sorted().joined(separator: ", ")).")
        }

        return BatteryNotifyRule(
            threshold: threshold,
            address: address,
            method: method,
            query: try strings(root["query"], key: "query"),
            headers: try strings(root["headers"], key: "headers"),
            body: (root["body"] as? String) ?? ""
        )
    }

    func makeRequest(percent: Int) throws -> URLRequest {
        guard var components = URLComponents(string: fill(address, percent)) else {
            throw BatteryNotifyError("\"url\" stops being a valid address once the level is filled in.")
        }
        if !query.isEmpty {
            // Escaped by hand rather than through `queryItems`, which leaves `+` raw (measured:
            // `%` becomes `%25` but `a+b` stays `a+b`) and so has the endpoint read a literal plus
            // as a space. Sorted so the same rule always produces the same URL.
            let escaped = query.sorted { $0.key < $1.key }
                .map { "\(Self.escape($0.key))=\(Self.escape(fill($0.value, percent)))" }
            components.percentEncodedQuery = ([components.percentEncodedQuery].compactMap { $0 } + escaped)
                .filter { !$0.isEmpty }
                .joined(separator: "&")
        }
        guard let url = components.url else {
            throw BatteryNotifyError("\"url\" and \"query\" do not combine into a valid address.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        // Bounded on purpose: a hung endpoint must not hold the retry slot open indefinitely.
        request.timeoutInterval = 15
        for (name, value) in headers {
            request.setValue(fill(value, percent), forHTTPHeaderField: name)
        }
        if !body.isEmpty, Self.methodsWithBody.contains(method) {
            request.httpBody = Data(fill(body, percent).utf8)
        }
        return request
    }

    /// Host only - used for logging, which must never carry the full url or a header token.
    var host: String {
        URLComponents(string: address)?.host ?? "?"
    }

    // MARK: - Internals

    private func fill(_ text: String, _ percent: Int) -> String {
        text.replacingOccurrences(of: Self.placeholder, with: String(percent))
    }

    private static func escape(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }

    /// Numbers and booleans are accepted and stringified: a rule is text on the wire, and rejecting
    /// `"retries": 3` would only be pedantry.
    private static func strings(_ value: Any?, key: String) throws -> [String: String] {
        guard let value, !(value is NSNull) else { return [:] }
        guard let dictionary = value as? [String: Any] else {
            throw BatteryNotifyError("\"\(key)\" must be a JSON object of name and value pairs.")
        }
        return try dictionary.mapValues { element in
            if let text = element as? String { return text }
            if let number = element as? NSNumber { return number.stringValue }
            throw BatteryNotifyError("Every value in \"\(key)\" must be a string or a number.")
        }
    }
}

/// Carries a message written for the dialog, so the editor can show it without translating.
nonisolated struct BatteryNotifyError: LocalizedError {
    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
