import Foundation

public enum DateParser {
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fallbackFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mmXXXXX",
            "yyyy-MM-dd'T'HH:mmX",
            "yyyy-MM-dd'T'HH:mmZ",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mmXXXXX",
            "yyyy-MM-dd HH:mmX",
            "yyyy-MM-dd HH:mmZ",
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy-MM-dd",
            "yyyy-M-d",
            "yyyy/MM/dd",
            "yyyy/M/d"
        ]
        return formats.map { format in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            df.dateFormat = format
            df.isLenient = false
            return df
        }
    }()

    /// Parses a date string into a Date object and indicates whether time was included
    public static func parse(_ string: String) -> (date: Date, hasTime: Bool)? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let date = iso8601WithFractionalSeconds.date(from: trimmed) {
            return (date, true)
        }
        if let date = iso8601Standard.date(from: trimmed) {
            return (date, true)
        }

        for formatter in fallbackFormatters {
            if let date = formatter.date(from: trimmed) {
                let format = formatter.dateFormat ?? ""
                let hasTime = format.contains("HH") || format.contains("mm")
                return (date, hasTime)
            }
        }

        return nil
    }

    /// Converts a Date to DateComponents for Reminders
    public static func toDateComponents(from date: Date, hasTime: Bool) -> DateComponents {
        let calendar = Calendar.current
        if hasTime {
            return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: date)
        } else {
            return calendar.dateComponents([.year, .month, .day], from: date)
        }
    }

    /// Converts DateComponents to formatted string
    public static func format(components: DateComponents?) -> String? {
        guard let components = components else { return nil }
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return nil }

        let hasTime = components.hour != nil && components.minute != nil
        return hasTime ? iso8601Standard.string(from: date) : dateOnlyFormatter.string(from: date)
    }

    /// Hoisted alongside the other cached formatters — this is called once per DTO,
    /// so allocating a DateFormatter here cost ~18µs per reminder returned.
    private static let dateOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    /// Formats Date into standard ISO 8601 string
    public static func format(date: Date?) -> String? {
        guard let date = date else { return nil }
        return iso8601Standard.string(from: date)
    }
}
