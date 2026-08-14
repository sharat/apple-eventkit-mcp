import Foundation
@preconcurrency import EventKit
import CoreGraphics

public enum ReminderError: LocalizedError, Sendable {
    case accessDenied
    case notFound(String)
    case invalidArgument(String)
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to Apple Reminders was denied. Please grant Reminders permission in macOS System Settings > Privacy & Security > Reminders."
        case .notFound(let msg):
            return "Item not found: \(msg)"
        case .invalidArgument(let msg):
            return "Invalid argument: \(msg)"
        case .operationFailed(let msg):
            return "Operation failed: \(msg)"
        }
    }
}

public actor EventKitManager {
    private let eventStore = EKEventStore()
    private var isAuthorized = false

    public init() {}

    /// Requests authorization to access Reminders
    public func ensureAuthorized() async throws {
        if isAuthorized { return }

        // The package deployment target is macOS 26.0, so full-access is always
        // available; the legacy requestAccess(to:) path would be unreachable.
        let granted = try await eventStore.requestFullAccessToReminders()
        guard granted else {
            throw ReminderError.accessDenied
        }
        isAuthorized = true
    }

    /// List all reminder lists (calendars of type reminder)
    public func listLists() async throws -> [ReminderListDTO] {
        try await ensureAuthorized()
        let defaultCal = eventStore.defaultCalendarForNewReminders()
        let calendars = eventStore.calendars(for: .reminder)

        return calendars.map { cal in
            ReminderListDTO(
                id: cal.calendarIdentifier,
                title: cal.title,
                color: ColorHex.hexString(from: cal.cgColor),
                isDefault: cal.calendarIdentifier == defaultCal?.calendarIdentifier
            )
        }
    }

    /// Helper to find a calendar by ID or unique Name (with safe ambiguity detection)
    private func resolveCalendar(identifier: String? = nil, name: String? = nil) throws -> EKCalendar {
        let cleanId = identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let validId = (cleanId?.isEmpty == false) ? cleanId : nil

        let cleanName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let validName = (cleanName?.isEmpty == false) ? cleanName : nil

        // Resolved by ID without enumerating every calendar — the common case.
        if let listId = validId {
            guard let cal = eventStore.calendar(withIdentifier: listId) else {
                throw ReminderError.notFound("No reminder list found with ID: '\(listId)'.")
            }
            return cal
        }

        let calendars = eventStore.calendars(for: .reminder)

        if let listName = validName {
            let matching = calendars.filter { $0.title.caseInsensitiveCompare(listName) == .orderedSame }
            if matching.isEmpty {
                throw ReminderError.notFound("No reminder list found with name: '\(listName)'.")
            }
            if matching.count > 1 {
                let matchesInfo = matching.map { "'\($0.title)' (ID: \($0.calendarIdentifier))" }.joined(separator: ", ")
                throw ReminderError.invalidArgument("Multiple reminder lists match '\(listName)': [\(matchesInfo)]. Please specify 'list_id'.")
            }
            return matching[0]
        }

        guard let defaultCal = eventStore.defaultCalendarForNewReminders() ?? calendars.first else {
            throw ReminderError.operationFailed("No default reminder list available in Apple Reminders.")
        }
        return defaultCal
    }

    /// Create a new reminder list
    public func createList(title: String, colorHex: String? = nil) async throws -> ReminderListDTO {
        try await ensureAuthorized()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw ReminderError.invalidArgument("List title cannot be empty.")
        }

        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = cleanTitle

        if let colorHex = colorHex, let cgColor = ColorHex.colorFromHex(colorHex) {
            calendar.cgColor = cgColor
        }

        // Assign appropriate source
        if let defaultSource = eventStore.defaultCalendarForNewReminders()?.source {
            calendar.source = defaultSource
        } else if let localOrCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV || $0.sourceType == .local }) {
            calendar.source = localOrCloudSource
        } else if let anySource = eventStore.sources.first {
            calendar.source = anySource
        } else {
            throw ReminderError.operationFailed("No available account source for creating a reminder list.")
        }

        try eventStore.saveCalendar(calendar, commit: true)

        let defaultCal = eventStore.defaultCalendarForNewReminders()
        return ReminderListDTO(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            color: ColorHex.hexString(from: calendar.cgColor),
            isDefault: calendar.calendarIdentifier == defaultCal?.calendarIdentifier
        )
    }

    /// Delete a reminder list
    public func deleteList(identifierOrTitle: String) async throws -> DeleteListResult {
        try await ensureAuthorized()
        let calendars = eventStore.calendars(for: .reminder)

        let targetCal: EKCalendar
        if let cal = calendars.first(where: { $0.calendarIdentifier == identifierOrTitle }) {
            targetCal = cal
        } else {
            let matching = calendars.filter { $0.title.caseInsensitiveCompare(identifierOrTitle) == .orderedSame }
            if matching.isEmpty {
                throw ReminderError.notFound("No reminder list found matching '\(identifierOrTitle)'.")
            }
            if matching.count > 1 {
                let matchesInfo = matching.map { "'\($0.title)' (ID: \($0.calendarIdentifier))" }.joined(separator: ", ")
                throw ReminderError.invalidArgument("Ambiguous delete request: multiple lists named '\(identifierOrTitle)' exist: [\(matchesInfo)]. Please pass 'list_id' to delete safely.")
            }
            targetCal = matching[0]
        }

        // Count reminders inside before deleting
        let predicate = eventStore.predicateForReminders(in: [targetCal])
        let remindersInside: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }
        let destroyedCount = remindersInside.count
        let listId = targetCal.calendarIdentifier
        let listTitle = targetCal.title

        try eventStore.removeCalendar(targetCal, commit: true)

        return DeleteListResult(
            id: listId,
            title: listTitle,
            deletedRemindersCount: destroyedCount,
            message: "Successfully deleted reminder list '\(listTitle)' and destroyed \(destroyedCount) reminder(s) inside it."
        )
    }

    /// List reminders with filtering and pagination
    public func listReminders(
        listName: String? = nil,
        listId: String? = nil,
        completed: Bool? = nil,
        dueAfter: String? = nil,
        dueBefore: String? = nil,
        searchQuery: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> RemindersQueryResult {
        try await ensureAuthorized()

        // Validate paging arguments (see Pagination for the boundary rules)
        let page = try Pagination.resolve(limit: limit, offset: offset)

        // Determine calendars to search in
        var targetCalendars: [EKCalendar]? = nil
        let cleanId = listId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let validId = (cleanId?.isEmpty == false) ? cleanId : nil
        let cleanName = listName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let validName = (cleanName?.isEmpty == false) ? cleanName : nil

        if let listId = validId {
            if let cal = eventStore.calendar(withIdentifier: listId) {
                targetCalendars = [cal]
            } else {
                throw ReminderError.notFound("No reminder list found with ID: \(listId)")
            }
        } else if let listName = validName {
            let calendars = eventStore.calendars(for: .reminder)
            let matching = calendars.filter { $0.title.caseInsensitiveCompare(listName) == .orderedSame }
            if matching.isEmpty {
                throw ReminderError.notFound("No reminder list found with name: \(listName)")
            }
            targetCalendars = matching
        }

        let predicate = eventStore.predicateForReminders(in: targetCalendars)

        let rawReminders: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        var results = rawReminders

        // Filter by completion
        if let completed = completed {
            results = results.filter { $0.isCompleted == completed }
        }

        // Decorate once. DateComponents -> Date is the dominant cost in this method,
        // and the due date is needed by both date filters and by every sort
        // comparison. Computing it per comparison meant ~2 conversions per compare
        // (~38k for 1000 reminders) instead of one per reminder.
        let cal = Calendar.current
        var decorated: [(key: ReminderSortKey, reminder: EKReminder)] = results.map { reminder in
            let due = reminder.dueDateComponents.flatMap { cal.date(from: $0) }
            let key = ReminderSortKey(
                isCompleted: reminder.isCompleted,
                dueDate: due,
                priority: reminder.priority,
                title: reminder.title ?? ""
            )
            return (key, reminder)
        }

        // Filter by due dates
        if let dueAfterStr = dueAfter?.trimmingCharacters(in: .whitespacesAndNewlines), !dueAfterStr.isEmpty {
            guard let (afterDate, _) = DateParser.parse(dueAfterStr) else {
                throw ReminderError.invalidArgument("Invalid 'due_after' date format: '\(dueAfterStr)'. Expected ISO 8601 date string.")
            }
            decorated = decorated.filter { entry in
                guard let date = entry.key.dueDate else { return false }
                return date >= afterDate
            }
        }

        if let dueBeforeStr = dueBefore?.trimmingCharacters(in: .whitespacesAndNewlines), !dueBeforeStr.isEmpty {
            guard let (beforeDate, hasTime) = DateParser.parse(dueBeforeStr) else {
                throw ReminderError.invalidArgument("Invalid 'due_before' date format: '\(dueBeforeStr)'. Expected ISO 8601 date string.")
            }
            let effectiveBeforeDate: Date
            if !hasTime {
                var comp = cal.dateComponents([.year, .month, .day], from: beforeDate)
                comp.hour = 23
                comp.minute = 59
                comp.second = 59
                effectiveBeforeDate = cal.date(from: comp) ?? beforeDate
            } else {
                effectiveBeforeDate = beforeDate
            }
            decorated = decorated.filter { entry in
                guard let date = entry.key.dueDate else { return false }
                return date <= effectiveBeforeDate
            }
        }

        // Filter by search query
        if let query = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            let lowerQuery = query.lowercased()
            decorated = decorated.filter { entry in
                let titleMatch = entry.reminder.title?.lowercased().contains(lowerQuery) ?? false
                let notesMatch = entry.reminder.notes?.lowercased().contains(lowerQuery) ?? false
                return titleMatch || notesMatch
            }
        }

        // Sort on the precomputed keys
        decorated.sort { reminderSortsBefore($0.key, $1.key) }

        let totalCount = decorated.count
        let defaultCal = eventStore.defaultCalendarForNewReminders()
        let dtos = decorated[page.window(totalCount: totalCount)].map {
            self.toDTO($0.reminder, defaultCalId: defaultCal?.calendarIdentifier)
        }

        return RemindersQueryResult(
            reminders: dtos,
            totalCount: totalCount,
            returnedCount: dtos.count,
            offset: page.offset,
            hasMore: page.hasMore(totalCount: totalCount)
        )
    }

    /// Create a new reminder
    public func createReminder(
        title: String,
        notes: String? = nil,
        listName: String? = nil,
        listId: String? = nil,
        dueDate: String? = nil,
        priority: AnyCodable? = nil,
        url: String? = nil
    ) async throws -> ReminderDTO {
        try await ensureAuthorized()

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw ReminderError.invalidArgument("Reminder title cannot be empty.")
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = cleanTitle
        reminder.notes = notes

        // Target calendar resolution
        reminder.calendar = try resolveCalendar(identifier: listId, name: listName)

        // Due date & Alarms
        if let dueDateStr = dueDate, !dueDateStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let (parsedDate, hasTime) = DateParser.parse(dueDateStr) else {
                throw ReminderError.invalidArgument("Invalid date format '\(dueDateStr)'. Expected ISO 8601 (e.g. '2026-08-14' or '2026-08-14T15:00:00Z').")
            }
            reminder.dueDateComponents = DateParser.toDateComponents(from: parsedDate, hasTime: hasTime)

            // For timed reminders, alarm triggers at exact time. For date-only reminders, alarm defaults to 9:00 AM.
            if hasTime {
                reminder.addAlarm(EKAlarm(absoluteDate: parsedDate))
            } else if let alarmDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: parsedDate) {
                reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
            }
        }

        // Priority
        if let priority = priority {
            reminder.priority = try Priority.parse(priority)
        }

        // URL
        if let urlStr = url, !urlStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reminder.url = try URLValidator.validate(urlStr)
        }

        try eventStore.save(reminder, commit: true)

        let defaultCal = eventStore.defaultCalendarForNewReminders()
        return toDTO(reminder, defaultCalId: defaultCal?.calendarIdentifier)
    }

    /// Update an existing reminder
    public func updateReminder(
        id: String,
        title: String? = nil,
        notes: String? = nil,
        listName: String? = nil,
        listId: String? = nil,
        dueDate: String? = nil,
        clearDueDate: Bool? = nil,
        priority: AnyCodable? = nil,
        completed: Bool? = nil,
        url: String? = nil
    ) async throws -> ReminderDTO {
        try await ensureAuthorized()

        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.notFound("No reminder found with ID: \(id)")
        }

        if let title = title {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else {
                throw ReminderError.invalidArgument("Reminder title cannot be empty.")
            }
            reminder.title = cleanTitle
        }

        if let notes = notes {
            reminder.notes = notes.isEmpty ? nil : notes
        }

        // Move to list
        if listId != nil || listName != nil {
            reminder.calendar = try resolveCalendar(identifier: listId, name: listName)
        }

        let wasCompleted = reminder.isCompleted
        let existingCompletionDate = reminder.completionDate
        let willBeCompleted = completed ?? wasCompleted

        // Due date & Alarms
        let trimmedDueDate = dueDate?.trimmingCharacters(in: .whitespacesAndNewlines)
        if clearDueDate == true || (trimmedDueDate != nil && trimmedDueDate!.isEmpty) {
            reminder.dueDateComponents = nil
            reminder.alarms?.forEach { reminder.removeAlarm($0) }
        } else if let dueDateStr = trimmedDueDate, !dueDateStr.isEmpty {
            guard let (parsedDate, hasTime) = DateParser.parse(dueDateStr) else {
                throw ReminderError.invalidArgument("Invalid date format '\(dueDateStr)'. Expected ISO 8601.")
            }
            reminder.dueDateComponents = DateParser.toDateComponents(from: parsedDate, hasTime: hasTime)
            reminder.alarms?.forEach { reminder.removeAlarm($0) }

            // Only attach an active alarm if the reminder is pending/incomplete
            if !willBeCompleted {
                if hasTime {
                    reminder.addAlarm(EKAlarm(absoluteDate: parsedDate))
                } else if let alarmDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: parsedDate) {
                    reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
                }
            }
        }

        // Priority
        if let priority = priority {
            reminder.priority = try Priority.parse(priority)
        }

        // Completion status
        if let completed = completed {
            reminder.isCompleted = completed
            reminder.completionDate = completed ? (existingCompletionDate ?? Date()) : nil

            // If reopening and due date exists in future without alarm, re-attach alarm
            if !completed, let components = reminder.dueDateComponents, let date = Calendar.current.date(from: components) {
                let hasTime = components.hour != nil
                let targetAlarmDate = hasTime ? date : Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date)
                if let alarmDate = targetAlarmDate, alarmDate > Date() {
                    if reminder.alarms == nil || reminder.alarms!.isEmpty {
                        reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
                    }
                }
            }
        } else if wasCompleted {
            // Prevent EventKit side-effects from uncompleting already completed tasks
            reminder.isCompleted = true
            reminder.completionDate = existingCompletionDate
        }

        // URL
        if let urlStr = url {
            let cleanURL = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanURL.isEmpty {
                reminder.url = nil
            } else {
                reminder.url = try URLValidator.validate(cleanURL)
            }
        }

        try eventStore.save(reminder, commit: true)

        let defaultCal = eventStore.defaultCalendarForNewReminders()
        return toDTO(reminder, defaultCalId: defaultCal?.calendarIdentifier, wasCompleted: wasCompleted)
    }

    /// Complete or uncomplete a reminder
    public func completeReminder(id: String, completed: Bool = true) async throws -> ReminderDTO {
        try await ensureAuthorized()

        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.notFound("No reminder found with ID: \(id)")
        }

        let wasCompleted = reminder.isCompleted
        let existingCompletionDate = reminder.completionDate

        reminder.isCompleted = completed
        if completed {
            reminder.completionDate = wasCompleted ? (existingCompletionDate ?? Date()) : Date()
        } else {
            reminder.completionDate = nil
            // If reopening, re-add alarm if future due date exists
            if let components = reminder.dueDateComponents, let date = Calendar.current.date(from: components) {
                let hasTime = components.hour != nil
                let targetAlarmDate = hasTime ? date : Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date)
                if let alarmDate = targetAlarmDate, alarmDate > Date() {
                    if reminder.alarms == nil || reminder.alarms!.isEmpty {
                        reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
                    }
                }
            }
        }

        try eventStore.save(reminder, commit: true)

        let defaultCal = eventStore.defaultCalendarForNewReminders()
        return toDTO(reminder, defaultCalId: defaultCal?.calendarIdentifier, wasCompleted: wasCompleted)
    }

    /// Delete a reminder
    public func deleteReminder(id: String) async throws -> DeleteReminderResult {
        try await ensureAuthorized()

        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.notFound("No reminder found with ID: \(id)")
        }

        let title = reminder.title ?? "Untitled"
        let listTitle = reminder.calendar?.title ?? "Reminders"

        try eventStore.remove(reminder, commit: true)

        return DeleteReminderResult(
            id: id,
            title: title,
            listTitle: listTitle,
            message: "Successfully deleted reminder '\(title)' from list '\(listTitle)' (ID: \(id))."
        )
    }

    // MARK: - Helpers

    private func toDTO(_ reminder: EKReminder, defaultCalId: String?, wasCompleted: Bool? = nil) -> ReminderDTO {
        let cal = reminder.calendar
        let listDTO = ReminderListDTO(
            id: cal?.calendarIdentifier ?? "unknown",
            title: cal?.title ?? "Reminders",
            color: ColorHex.hexString(from: cal?.cgColor),
            isDefault: cal != nil && cal?.calendarIdentifier == defaultCalId
        )

        return ReminderDTO(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes,
            isCompleted: reminder.isCompleted,
            wasCompleted: wasCompleted,
            completionDate: DateParser.format(date: reminder.completionDate),
            dueDate: DateParser.format(components: reminder.dueDateComponents),
            priority: reminder.priority,
            priorityLevel: Priority.name(for: reminder.priority),
            list: listDTO,
            url: reminder.url?.absoluteString,
            creationDate: DateParser.format(date: reminder.creationDate),
            lastModifiedDate: DateParser.format(date: reminder.lastModifiedDate)
        )
    }
}
