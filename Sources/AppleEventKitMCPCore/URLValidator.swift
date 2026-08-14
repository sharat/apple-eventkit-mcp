import Foundation

/// Scheme allow-list for URLs persisted onto reminders.
///
/// `reminder.url` is rendered as a clickable link in Reminders.app, so an
/// unrestricted `URL(string:)` would let a prompt-injected agent file a
/// benign-looking reminder carrying a `javascript:`, `data:`, `file:` or custom
/// app scheme (e.g. `shortcuts://x-callback-url/run-shortcut`) that the user
/// activates days later. Only schemes that are inert-until-navigated are allowed.
public enum URLValidator: Sendable {
    public static let allowedSchemes: Set<String> = ["https", "http", "mailto"]

    public static func validate(_ urlStr: String) throws -> URL {
        let clean = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: clean), let scheme = url.scheme?.lowercased() else {
            throw ReminderError.invalidArgument("Invalid URL format: '\(urlStr)'. A scheme is required (e.g. 'https://').")
        }
        guard allowedSchemes.contains(scheme) else {
            throw ReminderError.invalidArgument(
                "URL scheme '\(scheme):' is not allowed for security reasons. Allowed schemes: https, http, mailto."
            )
        }
        return url
    }
}
