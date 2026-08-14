import Testing
import Foundation
@testable import AppleEventKitMCPCore

struct PriorityTests {
    @Test func prioritySynonyms() throws {
        #expect(try Priority.parse(AnyCodable("high")) == 1)
        #expect(try Priority.parse(AnyCodable("urgent")) == 1)
        #expect(try Priority.parse(AnyCodable("critical")) == 1)
        #expect(try Priority.parse(AnyCodable("p1")) == 1)
        #expect(try Priority.parse(AnyCodable("1")) == 1)
        #expect(try Priority.parse(AnyCodable(1)) == 1)

        #expect(try Priority.parse(AnyCodable("medium")) == 5)
        #expect(try Priority.parse(AnyCodable("med")) == 5)
        #expect(try Priority.parse(AnyCodable("normal")) == 5)
        #expect(try Priority.parse(AnyCodable("p2")) == 5)
        #expect(try Priority.parse(AnyCodable(5)) == 5)

        #expect(try Priority.parse(AnyCodable("low")) == 9)
        #expect(try Priority.parse(AnyCodable("minor")) == 9)
        #expect(try Priority.parse(AnyCodable("p3")) == 9)
        #expect(try Priority.parse(AnyCodable(9)) == 9)

        #expect(try Priority.parse(AnyCodable("none")) == 0)
        #expect(try Priority.parse(AnyCodable("clear")) == 0)
        #expect(try Priority.parse(AnyCodable("p0")) == 0)
        #expect(try Priority.parse(AnyCodable(0)) == 0)
    }

    @Test func priorityRanking() {
        #expect(Priority.rank(for: 1) == 1)
        #expect(Priority.rank(for: 3) == 1)
        #expect(Priority.rank(for: 5) == 2)
        #expect(Priority.rank(for: 9) == 3)
        #expect(Priority.rank(for: 0) == 4)
    }

    @Test func priorityNames() {
        #expect(Priority.name(for: 1) == "high")
        #expect(Priority.name(for: 4) == "high")
        #expect(Priority.name(for: 5) == "medium")
        #expect(Priority.name(for: 9) == "low")
        #expect(Priority.name(for: 0) == "none")
    }

    @Test func unknownPriorityThrows() {
        #expect(throws: ReminderError.self) {
            _ = try Priority.parse(AnyCodable("banana"))
        }
        #expect(throws: ReminderError.self) {
            _ = try Priority.parse(AnyCodable("super-urgent"))
        }
        #expect(throws: ReminderError.self) {
            _ = try Priority.parse(AnyCodable(42))
        }
    }
}
