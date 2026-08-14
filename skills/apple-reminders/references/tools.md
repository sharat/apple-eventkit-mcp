# Apple EventKit MCP Tools Reference

Detailed schema documentation and tool behavior for `apple-eventkit-mcp`.

---

## 1. `list_reminders`
Retrieve reminders from Apple Reminders with rich filtering and pagination.

### Arguments
| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `completed` | boolean | No | `true` for completed only, `false` for pending/incomplete only. Omit for all. |
| `list_name` | string | No | Filter by calendar/list name (case-insensitive). |
| `list_id` | string | No | Filter by list UUID. |
| `due_after` | string | No | ISO 8601 timestamp or date (`YYYY-MM-DD` or `YYYY-MM-DDTHH:mm:ssZ`). |
| `due_before` | string | No | ISO 8601 timestamp or date. For date-only input, automatically extends to end-of-day (`23:59:59`). |
| `search_query`| string | No | Substring match against reminder title and notes. |
| `limit` | integer | No | Maximum number of reminders to return (1 to 1000, default: 50). |
| `offset` | integer | No | Index of the first item to return for pagination (default: 0). |

### Response Format
```json
{
  "reminders": [ ... ],
  "total_count": 128,
  "returned_count": 50,
  "offset": 0,
  "has_more": true
}
```

---

## 2. `create_reminder`
Create a new reminder with optional alarm, priority, notes, and URL.

### Arguments
| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `title` | string | **Yes** | Reminder title. |
| `notes` | string | No | Detailed description / notes. |
| `due_date` | string | No | ISO 8601 date or date-time (e.g., `2026-08-15T15:00:00+05:30` or `2026-08-15`). Timed dates trigger at the exact time; date-only items schedule a notification at **9:00 AM** on that date. |
| `list_name` | string | No | Target list name (defaults to default reminder list). If multiple lists share the name across accounts, specify `list_id`. |
| `list_id` | string | No | Target list UUID (takes precedence over `list_name`). |
| `priority` | string/int | No | Priority level: `none` (0), `low` (9), `medium` (5), `high` (1). Synonyms like `urgent`, `critical`, `p1`, `p2`, `p3` are supported. |
| `url` | string | No | Associated URL link (`https:`, `http:`, or `mailto:` schemes allowed). |

---

## 3. `update_reminder`
Update an existing reminder. Preserves completion state unless explicitly changed.

### Arguments
| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | string | **Yes** | Unique identifier of the reminder. |
| `title` | string | No | New title. |
| `notes` | string | No | New notes. |
| `due_date` | string | No | New ISO 8601 due date/time. Passing `""` or whitespace clears due date. |
| `clear_due_date` | boolean | No | Set `true` to remove due date and alarms. |
| `completed` | boolean | No | Mark completed (`true`) or active (`false`). Re-completing is idempotent; uncompleting restores alarms for future due dates. |
| `priority` | string/int | No | New priority level. |
| `list_name` | string | No | Move reminder to another list. |
| `list_id` | string | No | Move reminder to list with this UUID. |
| `url` | string | No | New URL link (`https:`, `http:`, `mailto:`). Pass empty string to remove. |

---

## 4. `complete_reminder`
Mark a reminder as completed or uncompleted.

### Arguments
| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | string | **Yes** | Unique identifier of the reminder. |
| `completed` | boolean | No | `true` (default) to complete, `false` to mark pending/active. Idempotent on completed items. |

---

## 5. `delete_reminder`
Permanently delete a reminder by ID. *(Requires explicit user confirmation)*.

### Arguments
| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | string | **Yes** | Unique identifier of the reminder to permanently delete. |

### Response Format
Returns the deleted reminder's title, list name, and ID to ensure accountability.

---

## 6. `list_reminder_lists`
List all reminder lists/categories with their names, IDs, hex color codes, and default status.

### Arguments
None.

---

## 7. `create_reminder_list`
Create a new reminder list.

### Arguments
| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `title` | string | **Yes** | Title of the new list. |
| `color` | string | No | Optional hex color (e.g. `#FF5733` or `#34C759`). |

---

## 8. `delete_reminder_list`
Permanently delete an entire list and all reminders inside it. *(DANGEROUS / DESTRUCTIVE — Requires explicit user confirmation)*.

### Arguments
| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `list_name` | string | No | Name of the list to delete (must be unambiguous across accounts). |
| `list_id` | string | No | UUID of the list to delete (preferred for precision). |

### Response Format
Returns the list name and the count of reminders destroyed inside it.
