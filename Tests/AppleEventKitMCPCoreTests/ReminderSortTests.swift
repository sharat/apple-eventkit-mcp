import Testing
import Foundation
@testable import AppleEventKitMCPCore

struct ReminderSortTests {
    @Test func incompleteSortsBeforeComplete() {
        let now = Date()
        let active = ReminderSortKey(isCompleted: false, dueDate: now, priority: 0, title: "Z")
        let done = ReminderSortKey(isCompleted: true, dueDate: now, priority: 1, title: "A")

        #expect(reminderSortsBefore(active, done))
        #expect(!reminderSortsBefore(done, active))
    }

    @Test func dueDateSortOrdering() {
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)

        let k1 = ReminderSortKey(isCompleted: false, dueDate: early, priority: 0, title: "B")
        let k2 = ReminderSortKey(isCompleted: false, dueDate: late, priority: 0, title: "A")
        let k3 = ReminderSortKey(isCompleted: false, dueDate: nil, priority: 0, title: "A")

        #expect(reminderSortsBefore(k1, k2))
        #expect(reminderSortsBefore(k2, k3))
    }

    @Test func prioritySortOrdering() {
        let now = Date(timeIntervalSince1970: 1000)
        let high = ReminderSortKey(isCompleted: false, dueDate: now, priority: 1, title: "B")
        let med = ReminderSortKey(isCompleted: false, dueDate: now, priority: 5, title: "A")
        let low = ReminderSortKey(isCompleted: false, dueDate: now, priority: 9, title: "A")
        let none = ReminderSortKey(isCompleted: false, dueDate: now, priority: 0, title: "A")

        #expect(reminderSortsBefore(high, med))
        #expect(reminderSortsBefore(med, low))
        #expect(reminderSortsBefore(low, none))
    }
}
