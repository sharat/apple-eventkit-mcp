import Foundation

public struct ReminderSortKey: Sendable, Equatable {
    public let isCompleted: Bool
    public let dueDate: Date?
    public let priority: Int
    public let title: String

    public init(isCompleted: Bool, dueDate: Date?, priority: Int, title: String) {
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.title = title
    }
}

public func reminderSortsBefore(_ a: ReminderSortKey, _ b: ReminderSortKey) -> Bool {
    if a.isCompleted != b.isCompleted {
        return !a.isCompleted // Incomplete first
    }

    if let d1 = a.dueDate, let d2 = b.dueDate, d1 != d2 {
        return d1 < d2
    }
    if a.dueDate != nil && b.dueDate == nil { return true }
    if a.dueDate == nil && b.dueDate != nil { return false }

    let rank1 = Priority.rank(for: a.priority)
    let rank2 = Priority.rank(for: b.priority)
    if rank1 != rank2 {
        return rank1 < rank2
    }

    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
}
