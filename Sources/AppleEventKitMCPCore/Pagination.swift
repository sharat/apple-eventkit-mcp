/// Page-window arithmetic for `list_reminders`.
///
/// Extracted from `EventKitManager.listReminders` so the boundary behaviour is
/// unit-testable without an `EKEventStore`. `has_more` is only trustworthy if
/// this arithmetic is right — a client that pages on a wrong `has_more` either
/// loops forever or silently drops the tail.
public struct Pagination: Sendable {
    public static let defaultLimit = 50
    public static let maxLimit = 1000

    public let offset: Int
    public let limit: Int

    /// Validates caller-supplied paging arguments, applying defaults for `nil`.
    public static func resolve(limit: Int?, offset: Int?) throws -> Pagination {
        let effectiveLimit: Int
        if let limit = limit {
            guard limit >= 1 && limit <= maxLimit else {
                throw ReminderError.invalidArgument(
                    "Limit must be a positive integer between 1 and \(maxLimit). Received: \(limit)"
                )
            }
            effectiveLimit = limit
        } else {
            effectiveLimit = defaultLimit
        }

        let effectiveOffset: Int
        if let offset = offset {
            guard offset >= 0 else {
                throw ReminderError.invalidArgument("Offset must be non-negative (>= 0). Received: \(offset)")
            }
            effectiveOffset = offset
        } else {
            effectiveOffset = 0
        }

        return Pagination(offset: effectiveOffset, limit: effectiveLimit)
    }

    /// The half-open window into a result set of `totalCount` items.
    /// Empty when the offset is at or past the end. The empty range is anchored at
    /// `totalCount`, not zero, so `hasMore` stays correct past the end and the range
    /// is always a valid slice index.
    public func window(totalCount: Int) -> Range<Int> {
        let start = min(offset, totalCount)
        return start..<min(start + limit, totalCount)
    }

    /// True when items remain after the returned window. Derived from `window`
    /// rather than taking a caller-supplied count, so the two cannot disagree.
    public func hasMore(totalCount: Int) -> Bool {
        window(totalCount: totalCount).upperBound < totalCount
    }
}
