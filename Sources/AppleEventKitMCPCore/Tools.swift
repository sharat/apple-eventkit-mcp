import Foundation

public final class ReminderTools: Sendable {
    private let eventKitManager: EventKitManager

    public init(eventKitManager: EventKitManager) {
        self.eventKitManager = eventKitManager
    }

    public var definitions: [ToolDefinition] {
        [
            ToolDefinition(
                name: "list_reminder_lists",
                description: "List all reminder lists (categories/calendars) available in Apple Reminders.",
                inputSchema: [
                    "type": "object",
                    "properties": [:] as [String: Any]
                ]
            ),
            ToolDefinition(
                name: "create_reminder_list",
                description: "Create a new reminder list (category) in Apple Reminders.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Name/title for the new reminder list"
                        ],
                        "color": [
                            "type": "string",
                            "description": "Optional hex color for the list (e.g. '#FF5733', '#34C759')"
                        ]
                    ],
                    "required": ["title"]
                ]
            ),
            ToolDefinition(
                name: "delete_reminder_list",
                description: "DANGEROUS & DESTRUCTIVE: Permanently delete an existing reminder list and ALL reminders contained inside it. Always ask for explicit user confirmation before executing.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "list_name": [
                            "type": "string",
                            "description": "Name of the reminder list to delete (if unique)"
                        ],
                        "list_id": [
                            "type": "string",
                            "description": "Unique identifier of the reminder list to delete (preferred for precision)"
                        ]
                    ]
                ]
            ),
            ToolDefinition(
                name: "list_reminders",
                description: "Get reminders with filtering by list name/id, completion status (pass completed: false for active tasks), due dates, or search query. Returns total_count, returned_count, offset, and has_more for pagination.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "list_name": [
                            "type": "string",
                            "description": "Optional name of the reminder list to filter by"
                        ],
                        "list_id": [
                            "type": "string",
                            "description": "Optional identifier of the reminder list to filter by"
                        ],
                        "completed": [
                            "type": "boolean",
                            "description": "Filter by completion status: true for completed only, false for pending/incomplete only. For updating, rescheduling, or daily planning, pass false to only target active tasks."
                        ],
                        "due_after": [
                            "type": "string",
                            "description": "Filter reminders due on or after this ISO 8601 date/time (e.g. '2026-08-14' or '2026-08-14T00:00:00Z')"
                        ],
                        "due_before": [
                            "type": "string",
                            "description": "Filter reminders due on or before this ISO 8601 date/time"
                        ],
                        "search_query": [
                            "type": "string",
                            "description": "Search text to match against reminder title and notes"
                        ],
                        "limit": [
                            "type": "integer",
                            "minimum": 1,
                            "maximum": Pagination.maxLimit,
                            "description": "Maximum number of reminders to return (1 to \(Pagination.maxLimit), default: \(Pagination.defaultLimit))"
                        ],
                        "offset": [
                            "type": "integer",
                            "minimum": 0,
                            "description": "Pagination offset (index of the first reminder to return, default: 0)"
                        ]
                    ]
                ]
            ),
            ToolDefinition(
                name: "create_reminder",
                description: "Create a new reminder in Apple Reminders with optional due date, notes, list, priority, and URL.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Title of the reminder (required)"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Optional notes or details for the reminder"
                        ],
                        "list_name": [
                            "type": "string",
                            "description": "Optional name of the target list (defaults to default list)"
                        ],
                        "list_id": [
                            "type": "string",
                            "description": "Optional ID of the target list"
                        ],
                        "due_date": [
                            "type": "string",
                            "description": "Optional ISO 8601 due date/time (e.g. '2026-08-14T17:00:00+05:30' or '2026-08-14')"
                        ],
                        "priority": [
                            "description": "Priority: 'none', 'low', 'medium', 'high', or integer 0-9 (0=none, 1=high, 5=medium, 9=low)",
                            "oneOf": [
                                ["type": "string"],
                                ["type": "integer"]
                            ]
                        ],
                        "url": [
                            "type": "string",
                            "description": "Optional URL link (https, http, mailto) attached to the reminder"
                        ]
                    ],
                    "required": ["title"]
                ]
            ),
            ToolDefinition(
                name: "update_reminder",
                description: "Update an existing reminder in Apple Reminders (title, notes, due date, list, priority, completion). Preserves completion status unless explicitly changed.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "id": [
                            "type": "string",
                            "description": "The unique identifier of the reminder to update (required)"
                        ],
                        "title": [
                            "type": "string",
                            "description": "New title for the reminder"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "New notes for the reminder"
                        ],
                        "list_name": [
                            "type": "string",
                            "description": "Move reminder to the list with this name"
                        ],
                        "list_id": [
                            "type": "string",
                            "description": "Move reminder to the list with this ID"
                        ],
                        "due_date": [
                            "type": "string",
                            "description": "New due date in ISO 8601 format"
                        ],
                        "clear_due_date": [
                            "type": "boolean",
                            "description": "Set to true to remove the due date and alarms"
                        ],
                        "priority": [
                            "description": "New priority: 'none', 'low', 'medium', 'high', or integer 0-9",
                            "oneOf": [
                                ["type": "string"],
                                ["type": "integer"]
                            ]
                        ],
                        "completed": [
                            "type": "boolean",
                            "description": "Mark as completed (true) or uncompleted (false)"
                        ],
                        "url": [
                            "type": "string",
                            "description": "New URL attached to the reminder (pass empty string to remove)"
                        ]
                    ],
                    "required": ["id"]
                ]
            ),
            ToolDefinition(
                name: "complete_reminder",
                description: "Mark a reminder as completed (true, default) or active/pending (false) by ID. Idempotent on already-completed tasks.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "id": [
                            "type": "string",
                            "description": "The unique identifier of the reminder (required)"
                        ],
                        "completed": [
                            "type": "boolean",
                            "description": "Whether to mark the reminder completed (true, default) or pending (false)"
                        ]
                    ],
                    "required": ["id"]
                ]
            ),
            ToolDefinition(
                name: "delete_reminder",
                description: "DANGEROUS & DESTRUCTIVE: Permanently delete a reminder by ID. For finished tasks, prefer complete_reminder. Always confirm with the user before deleting.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "id": [
                            "type": "string",
                            "description": "The unique identifier of the reminder to permanently delete (required)"
                        ]
                    ],
                    "required": ["id"]
                ]
            )
        ]
    }

    public func callTool(name: String, arguments: [String: AnyCodable]) async -> CallToolResult {
        do {
            switch name {
            case "list_reminder_lists":
                let lists = try await eventKitManager.listLists()
                let json = try formatJSON(lists)
                return CallToolResult(text: json)

            case "create_reminder_list":
                guard let title = arguments["title"]?.stringValue else {
                    return CallToolResult(text: "Missing required argument 'title'", isError: true)
                }
                let color = arguments["color"]?.stringValue
                let list = try await eventKitManager.createList(title: title, colorHex: color)
                let json = try formatJSON(list)
                return CallToolResult(text: json)

            case "delete_reminder_list":
                let cleanId = arguments["list_id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                let validId = (cleanId?.isEmpty == false) ? cleanId : nil

                let cleanName = arguments["list_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                let validName = (cleanName?.isEmpty == false) ? cleanName : nil

                guard let target = validId ?? validName else {
                    return CallToolResult(text: "Must provide either 'list_name' or 'list_id' to delete.", isError: true)
                }
                let result = try await eventKitManager.deleteList(identifierOrTitle: target)
                let json = try formatJSON(result)
                return CallToolResult(text: json)

            case "list_reminders":
                let listName = arguments["list_name"]?.stringValue
                let listId = arguments["list_id"]?.stringValue
                let completed = arguments["completed"]?.boolValue
                let dueAfter = arguments["due_after"]?.stringValue
                let dueBefore = arguments["due_before"]?.stringValue
                let searchQuery = arguments["search_query"]?.stringValue
                let limit = arguments["limit"]?.intValue
                let offset = arguments["offset"]?.intValue

                let queryResult = try await eventKitManager.listReminders(
                    listName: listName,
                    listId: listId,
                    completed: completed,
                    dueAfter: dueAfter,
                    dueBefore: dueBefore,
                    searchQuery: searchQuery,
                    limit: limit,
                    offset: offset
                )
                let json = try formatJSON(queryResult)
                return CallToolResult(text: json)

            case "create_reminder":
                guard let title = arguments["title"]?.stringValue else {
                    return CallToolResult(text: "Missing required argument 'title'", isError: true)
                }
                let notes = arguments["notes"]?.stringValue
                let listName = arguments["list_name"]?.stringValue
                let listId = arguments["list_id"]?.stringValue
                let dueDate = arguments["due_date"]?.stringValue
                let priority = arguments["priority"]
                let url = arguments["url"]?.stringValue

                let reminder = try await eventKitManager.createReminder(
                    title: title,
                    notes: notes,
                    listName: listName,
                    listId: listId,
                    dueDate: dueDate,
                    priority: priority,
                    url: url
                )
                let json = try formatJSON(reminder)
                return CallToolResult(text: json)

            case "update_reminder":
                guard let id = arguments["id"]?.stringValue else {
                    return CallToolResult(text: "Missing required argument 'id'", isError: true)
                }
                let title = arguments["title"]?.stringValue
                let notes = arguments["notes"]?.stringValue
                let listName = arguments["list_name"]?.stringValue
                let listId = arguments["list_id"]?.stringValue
                let dueDate = arguments["due_date"]?.stringValue
                let clearDueDate = arguments["clear_due_date"]?.boolValue
                let priority = arguments["priority"]
                let completed = arguments["completed"]?.boolValue
                let url = arguments["url"]?.stringValue

                let reminder = try await eventKitManager.updateReminder(
                    id: id,
                    title: title,
                    notes: notes,
                    listName: listName,
                    listId: listId,
                    dueDate: dueDate,
                    clearDueDate: clearDueDate,
                    priority: priority,
                    completed: completed,
                    url: url
                )
                let json = try formatJSON(reminder)
                return CallToolResult(text: json)

            case "complete_reminder":
                guard let id = arguments["id"]?.stringValue else {
                    return CallToolResult(text: "Missing required argument 'id'", isError: true)
                }
                let completed = arguments["completed"]?.boolValue ?? true
                let reminder = try await eventKitManager.completeReminder(id: id, completed: completed)
                let json = try formatJSON(reminder)
                return CallToolResult(text: json)

            case "delete_reminder":
                guard let id = arguments["id"]?.stringValue else {
                    return CallToolResult(text: "Missing required argument 'id'", isError: true)
                }
                let result = try await eventKitManager.deleteReminder(id: id)
                let json = try formatJSON(result)
                return CallToolResult(text: json)

            default:
                return CallToolResult(text: "Unknown tool: \(name)", isError: true)
            }
        } catch {
            Logger.error("Tool '\(name)' execution failed: \(error.localizedDescription)")
            return CallToolResult(text: "Error executing tool '\(name)': \(error.localizedDescription)", isError: true)
        }
    }

    private func formatJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
