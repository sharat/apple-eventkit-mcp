import Testing
import Foundation
@testable import AppleEventKitMCPCore

struct URLValidatorTests {
    @Test func allowsWebAndMailSchemes() throws {
        #expect(try URLValidator.validate("https://example.com/a?b=c").scheme == "https")
        #expect(try URLValidator.validate("http://example.com").scheme == "http")
        #expect(try URLValidator.validate("mailto:someone@example.com").scheme == "mailto")
    }

    @Test func schemeMatchingIsCaseInsensitive() throws {
        #expect(try URLValidator.validate("HTTPS://example.com").scheme?.lowercased() == "https")
        #expect(try URLValidator.validate("MailTo:someone@example.com").scheme?.lowercased() == "mailto")
    }

    @Test func handlesWhitespaceSurroundedURL() throws {
        let url = try URLValidator.validate("  https://example.com/clean  \n")
        #expect(url.absoluteString == "https://example.com/clean")
    }

    /// Each of these parses fine via `URL(string:)` and would previously have been
    /// persisted onto a reminder and rendered as a clickable link.
    @Test func rejectsDangerousSchemes() {
        let hostile = [
            "javascript:alert(1)",
            "data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==",
            "file:///etc/passwd",
            "shortcuts://x-callback-url/run-shortcut?name=Exfil",
            "ftp://example.com/payload",
            "x-apple-reminderkit://REMCDReminder/1",
        ]
        for candidate in hostile {
            #expect(throws: ReminderError.self, "expected \(candidate) to be rejected") {
                _ = try URLValidator.validate(candidate)
            }
        }
    }

    @Test func rejectsSchemelessAndMalformedInput() {
        for candidate in ["example.com", "/just/a/path", "", "   "] {
            #expect(throws: ReminderError.self, "expected \(candidate.debugDescription) to be rejected") {
                _ = try URLValidator.validate(candidate)
            }
        }
    }

    @Test func allowListIsExactlyTheExpectedSet() {
        #expect(URLValidator.allowedSchemes == ["https", "http", "mailto"])
    }
}
