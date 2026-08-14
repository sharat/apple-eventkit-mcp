import Testing
import Foundation
@testable import AppleEventKitMCPCore

struct DateParserTests {
    @Test func acceptValidDates() {
        // ISO 8601 with fractional seconds and UTC timezone
        let d1 = DateParser.parse("2026-08-14T15:00:00.123Z")
        #expect(d1 != nil)
        #expect(d1?.hasTime == true)

        // ISO 8601 standard
        let d2 = DateParser.parse("2026-08-14T15:00:00Z")
        #expect(d2 != nil)
        #expect(d2?.hasTime == true)

        // Standard date-time with space
        let d3 = DateParser.parse("2026-08-14 15:00")
        #expect(d3 != nil)
        #expect(d3?.hasTime == true)

        // Standard date-only
        let d4 = DateParser.parse("2026-08-14")
        #expect(d4 != nil)
        #expect(d4?.hasTime == false)

        // Non-padded date-only (2026-8-14)
        let d5 = DateParser.parse("2026-8-14")
        #expect(d5 != nil)
        #expect(d5?.hasTime == false)

        // Fractional seconds without timezone
        let d6 = DateParser.parse("2026-08-14T15:00:00.123")
        #expect(d6 != nil)
        #expect(d6?.hasTime == true)

        // Minute-precision ISO 8601 with Z and timezone offset
        let d7 = DateParser.parse("2026-08-14T15:00Z")
        #expect(d7 != nil)
        #expect(d7?.hasTime == true)

        let d8 = DateParser.parse("2026-08-14T15:00+05:30")
        #expect(d8 != nil)
        #expect(d8?.hasTime == true)
    }

    @Test func rejectInvalidAndGarbageDates() {
        #expect(DateParser.parse("2026-08-14lunchtime") == nil)
        #expect(DateParser.parse("tomorrow") == nil)
        #expect(DateParser.parse("2026-13-45") == nil)
        #expect(DateParser.parse("08/14/2026") == nil)
        #expect(DateParser.parse("") == nil)
        #expect(DateParser.parse("   ") == nil)
        #expect(DateParser.parse("invalid-string") == nil)
    }

    @Test func dateComponentsConversion() {
        let (date, hasTime) = DateParser.parse("2026-08-14T15:30:00Z")!
        let components = DateParser.toDateComponents(from: date, hasTime: hasTime)
        #expect(components.hour != nil)
        #expect(components.minute != nil)

        let (dateOnly, hasTimeOnly) = DateParser.parse("2026-08-14")!
        let dateOnlyComponents = DateParser.toDateComponents(from: dateOnly, hasTime: hasTimeOnly)
        #expect(dateOnlyComponents.hour == nil)
        #expect(dateOnlyComponents.minute == nil)
    }

    @Test func formatRoundTrip() {
        let original = "2026-08-14"
        let (date, hasTime) = DateParser.parse(original)!
        let components = DateParser.toDateComponents(from: date, hasTime: hasTime)
        let formatted = DateParser.format(components: components)
        #expect(formatted == "2026-08-14")
    }
}
