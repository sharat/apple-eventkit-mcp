import Testing
import Foundation
@testable import AppleEventKitMCPCore

struct AnyCodableTests {
    @Test func extremeFloatingPointDoesNotCrash() throws {
        // F.1 Regression test: 1e30 must not trap when accessing intValue
        let jsonString = "{\"limit\": 1e30}"
        let data = jsonString.data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(dict["limit"] != nil)
        // Must return nil safely instead of triggering fatalError
        let intVal = dict["limit"]?.intValue
        #expect(intVal == nil)
    }

    @Test func intMaxBoundaryDoesNotCrash() {
        let boundaryDouble = Double(Int.max) // 9223372036854775808.0 = 2^63
        let ac = AnyCodable(boundaryDouble)
        #expect(ac.intValue == nil)

        let strBoundary = AnyCodable("9223372036854775808")
        #expect(strBoundary.intValue == nil)

        let safeMax = AnyCodable(Int.max)
        #expect(safeMax.intValue == Int.max)
    }

    @Test func lenientAccessors() {
        let strTrue = AnyCodable("true")
        #expect(strTrue.boolValue == true)

        let strFalse = AnyCodable("false")
        #expect(strFalse.boolValue == false)

        let strNum = AnyCodable("123")
        #expect(strNum.intValue == 123)
        #expect(strNum.doubleValue == 123.0)

        let intVal = AnyCodable(42)
        #expect(intVal.intValue == 42)
        #expect(intVal.doubleValue == 42.0)
        #expect(intVal.stringValue == "42")
        #expect(intVal.boolValue == true)

        let zeroVal = AnyCodable(0)
        #expect(zeroVal.boolValue == false)
    }

    @Test func codableRoundTrip() throws {
        let original: [String: AnyCodable] = [
            "name": AnyCodable("Task"),
            "count": AnyCodable(5),
            "done": AnyCodable(false),
            "ratio": AnyCodable(3.14),
            "tags": AnyCodable(["urgent", "work"])
        ]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(decoded["name"]?.stringValue == "Task")
        #expect(decoded["count"]?.intValue == 5)
        #expect(decoded["done"]?.boolValue == false)
        #expect(decoded["tags"]?.arrayValue?.count == 2)
    }
}
