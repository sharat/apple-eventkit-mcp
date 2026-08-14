---
name: apple-reminders
description: Expert workflows, natural language date scheduling, and safety rules for querying, creating, prioritizing, completing, and managing Apple Reminders via the apple-eventkit-mcp server. Use when creating, querying, organizing, completing, rescheduling, or deleting reminders and reminder lists.
license: MIT
compatibility:
  os:
    - macos
  min_os_version: "26.0"
  tools:
    - list_reminders
    - create_reminder
    - update_reminder
    - complete_reminder
    - delete_reminder
    - list_reminder_lists
    - create_reminder_list
    - delete_reminder_list
metadata:
  author: sharat
  repository: https://github.com/sharat/apple-eventkit-mcp
---

# Apple Reminders Skill

Standard operating procedures and best practices for managing tasks, to-dos, and reminder lists using the `apple-eventkit-mcp` server.

---

## 💻 System Compatibility & Prerequisites

- **Supported Environment**: Supported on macOS 26.0 (Tahoe) or higher, Apple Silicon (`arm64`).
- **Graceful Failure on Unsupported Platforms**: If the current machine is not macOS or runs macOS < 26.0 (or Linux/Windows), gracefully explain that the Apple Reminders skill and `apple-eventkit-mcp` server cannot be installed or used on their platform, as it requires Apple EventKit on macOS 26.0+.
- **Setup on Supported Machines**: If tools are not detected in the current agent session on a compatible machine, instruct the user to install with:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/sharat/apple-eventkit-mcp/main/install.sh | bash
  ```

---

## 🛡️ Critical Safety & Dangerous Actions Rules

> [!CAUTION]
> **Data Loss & State Integrity Rules**:
> 1. **Complete vs. Delete**:
>    - When a user says *"I finished [task]"*, *"Done with [task]"*, or *"Check off [task]"*, **ALWAYS** call `complete_reminder(id: "...", completed: true)`. **NEVER** call `delete_reminder`.
>    - Deletion is permanent in Apple Reminders and cannot be undone. Only delete if the user explicitly asks to *"permanently delete"*, *"trash"*, or *"remove permanently"*.
> 2. **Never Process Done Tasks in Active Workflows**:
>    - All queries, searches, rescheduling, and updates **MUST** pass `completed: false` to target **only active/pending tasks**.
>    - Done tasks must never be included in daily briefings, batch moves, or time shifts (e.g. *"move all 12 AM tasks today to 10 PM"* must never touch finished tasks).
> 3. **Mandatory Warning When Operating on Done Tasks**:
>    - If a user asks to modify, reschedule, or delete a task that is **already marked as completed**, **DO NOT silently alter it**.
>    - You **MUST** warn the user first:
>      > ⚠️ **Notice**: *"'[Task Title]' was already completed on [Date]. Do you want to reopen and update this task, or leave it completed?"*
> 4. **Explicit Confirmation for Deletions**:
>    - **Individual Reminder Deletion (`delete_reminder`)**: Always state the exact title and list of the reminder before deleting, unless the user provided unequivocal instruction.
>    - **List Deletion (`delete_reminder_list`)**: **ALWAYS** ask for explicit confirmation before deleting a list. Warn the user that all reminders contained within that list will be permanently destroyed.
> 5. **Bulk Modifications**:
>    - When performing bulk operations affecting $\ge 3$ reminders (such as clearing due dates or moving items), show the target list and ask for user confirmation first.

---

## 🧭 Core Principles

1. **Active Task Scope by Default (`completed: false`)**:
   - Always query with `completed: false` unless the user explicitly requests completed history (e.g. *"What did I finish yesterday?"*).
   - Never reschedule, edit due dates on, or revive already completed tasks.

2. **Date & Time Anchoring**:
   - Always resolve relative time expressions (e.g. *"tomorrow at 2pm"*, *"in 3 hours"*, *"next Monday"*) into precise ISO 8601 strings (e.g. `2026-08-15T14:00:00+05:30` or `2026-08-15`) using the user's current local time and timezone.
   - For all-day tasks without a specific time, use date-only format (`YYYY-MM-DD`).

3. **Deduplication First**:
   - Before creating a new reminder, search active reminders (`completed: false`) to avoid creating duplicate entries.

4. **Intelligent List Routing**:
   - If the user doesn't specify a list, check available lists with `list_reminder_lists` or default to the user's default list.
   - Match common task categories to appropriate lists when they exist (e.g., groceries/items $\rightarrow$ `Shopping` / `Groceries`, financial deadlines $\rightarrow$ `Finance`, work tasks $\rightarrow$ `Work`).

---

## 🛠️ MCP Tools Overview

For full schema details, see [Tools Reference](references/tools.md).

- **`list_reminders`**: Retrieve reminders. Pass `completed: false` for active/pending tasks, `due_before`/`due_after` for date windows, `list_name` for specific categories, and `search_query` for text search.
- **`create_reminder`**: Add a reminder with `title`, optional `notes`, `due_date`, `list_name` (or `list_id`), `priority` (`high`, `medium`, `low`, `none`), and `url`.
- **`update_reminder`**: Modify fields on an existing reminder by `id`. Supports changing title, notes, list, priority, due date, or clearing due date (`clear_due_date: true`).
- **`complete_reminder`**: Mark task completed (`completed: true`) or uncompleted (`completed: false`) by `id`.
- **`delete_reminder`**: Permanently delete a reminder by `id`. *(Requires user intent / confirmation)*.
- **`list_reminder_lists`**: Inspect all available lists and their color codes.
- **`create_reminder_list`**: Create a new category list with `title` and optional hex `color`.
- **`delete_reminder_list`**: Remove a list and all reminders inside it. *(Requires explicit user confirmation)*.

---

## 📋 Common Workflows

### 1. Morning / Daily Task Briefing
1. Call `list_reminders` with `completed: false` and `due_before: <end_of_today>`.
2. Group and present tasks by List and Priority:
   - 🔴 **High Priority**: Overdue or urgent items.
   - 🟡 **Medium Priority**: Standard due tasks.
   - ⚪ **Normal / Low**: General tasks.
3. Present in a clean markdown checklist.

### 2. Adding Smart Reminders
1. Parse user input for title, date/time, notes, list preference, and priority.
2. Call `create_reminder` with the parsed parameters.
3. Confirm with a summary: `"Created reminder: '{title}' in list '{list}' due on {date} with {priority} priority."`

### 3. Triage & Completion
1. When user says *"I finished [task]"* or *"Mark [task] done"*:
   - Search for matching reminder using `list_reminders(search_query: "...")`.
   - Call `complete_reminder(id: "...", completed: true)`.
   - Confirm completion to user.

### 4. Rescheduling / Moving Active Tasks
1. When user asks to move or reschedule tasks (e.g., *"update all 12:00 AM tasks today to 10 PM"*):
   - Call `list_reminders` with `completed: false` and date filters to ensure **only pending** items are retrieved.
   - For each matching item, call `update_reminder(id: "...", due_date: "<new_iso_date>")`.
   - Confirm with count and titles of rescheduled active tasks.

---

## 🎨 Response Presentation Format

When presenting reminders to the user, format them clearly:

```markdown
### 📋 [List Name]
- [ ] **[Task Title]** `Due: Aug 15, 2:00 PM` 🔴 *High Priority*
  > *Notes: Additional context here*
- [ ] **[Another Task]** `Due: Today`
- [x] ~~**[Completed Task]**~~
```
