# AGENTS.md - Apple EventKit MCP Server

Guidelines, architecture overview, and operating principles for AI agents working in or with this repository.

---

## 🎯 Project Overview

`apple-eventkit-mcp` is a native macOS Model Context Protocol (MCP) server written entirely in Swift. It exposes Apple Reminders CRUD functionality to LLM clients (Claude Desktop, Cursor, Antigravity, Windsurf, Zed, Claude CLI) via standard JSON-RPC 2.0 over `stdio`.

- **Language**: Swift 5.9+ / Swift 6
- **Architecture**: Apple Silicon (`arm64` / M-series only)
- **Target OS**: macOS 26.0 (Tahoe) and later
- **Primary Framework**: Apple `EventKit` (`EKEventStore`, `EKReminder`, `EKCalendar`)
- **Protocol**: Model Context Protocol (MCP `2024-11-05`)

---

## 📁 Codebase Architecture

```
.
├── Package.swift                    # SPM manifest (macOS 26+, library + executable + tests)
├── Makefile                         # 'make build', 'make install' (/usr/local/bin)
├── install.sh                       # Verified universal installation script
├── Sources/
│   ├── AppleEventKitMCPCore/        # Core library target (testable logic & EventKit actor)
│   │   ├── MCPServer.swift          # Stdio transport loop, JSON-RPC routing & dispatch
│   │   ├── Tools.swift              # MCP Tool definitions, schemas & guard rails
│   │   ├── EventKitManager.swift    # EKEventStore actor managing Reminders & Calendars
│   │   ├── MCPTypes.swift           # Protocol DTOs, JSONRPCResponse & error types
│   │   ├── AnyCodable.swift         # Dynamic JSON encoder/decoder with non-trapping accessors
│   │   ├── DateParser.swift         # Resilient ISO 8601 / multi-format date parser
│   │   ├── Priority.swift           # Priority synonyms, integers 0-9 & ranking
│   │   ├── ReminderSort.swift       # Pure comparator for completion, date & priority
│   │   ├── ColorHex.swift           # sRGB CGColor hex parsing & conversion
│   │   ├── Pagination.swift         # limit/offset validation & page-window arithmetic
│   │   ├── URLValidator.swift       # Scheme allow-list for URLs persisted on reminders
│   │   └── Logger.swift             # Stderr-only logging (prevents stdout corruption)
│   └── apple-eventkit-mcp/
│       └── main.swift               # Thin executable entry point
├── Tests/
│   └── AppleEventKitMCPCoreTests/   # Unit & contract test suite
└── skills/
    └── apple-reminders/
        └── SKILL.md                 # Bundled agent skill for scheduling & triage
├── scripts/
│   └── protocol-conformance.sh      # stdio framing/exit-status check (CI + `make conformance`)
└── .github/workflows/
    ├── ci.yml                       # CI build, unit tests & protocol conformance
    └── release.yml                  # Tagged arm64 binary packaging & GH releases
```

---

## ⚠️ Critical Development Rules for Agents

### 1. Standard I/O Isolation (CRITICAL)
- **Standard Output (`stdout`) is strictly reserved for JSON-RPC 2.0 responses.**
- **NEVER** use `print()` or write debug info to `stdout`.
- All logging, errors, and diagnostic traces **MUST** use `Logger.info()`, `Logger.debug()`, `Logger.error()`, or `FileHandle.standardError`.

### 2. Zero External Dependencies
- Do not introduce CocoaPods, Carthage, npm, or third-party SPM packages unless explicitly requested.
- Pure Swift standard library + `EventKit` + `CoreGraphics` keeps the binary lightweight (~480 KB) and portable.

### 3. Swift Concurrency & EventKit
- `EKEventStore` operations are managed through the `EventKitManager` actor.
- Completion-handler based APIs (`fetchReminders(matching:)`) must be wrapped using `withCheckedThrowingContinuation`.
- Never force unwrap calendar references (`reminder.calendar`) to prevent crashes on orphaned or legacy items.

### 4. Resilient Date Handling
- Always use `DateParser.parse(_:)` for user/LLM date strings. It supports ISO 8601 full timestamps with timezones, date-only formats (`YYYY-MM-DD`), and common LLM outputs without seconds.

---

## 🛡️ Dangerous Action & Safety Protocol

1. **Complete vs Delete**:
   - Marking a task as finished $\rightarrow$ Use `complete_reminder(id: "...", completed: true)`.
   - **Never** substitute `complete_reminder` with `delete_reminder`. Deletion is permanent in Apple Reminders.
2. **Exclude Done Tasks by Default (`completed: false`)**:
   - All searches, listings, rescheduling, and updates must pass `completed: false` to only affect active tasks.
   - Never reschedule or revive completed tasks in batch or daily planning operations.
3. **Mandatory Warning on Completed Tasks**:
   - If user commands specifically target a completed task for modification or deletion, warn the user first with its completion date and request explicit confirmation before modifying.
4. **Explicit User Confirmation for Deletion**:
   - **`delete_reminder_list`**: Always ask for explicit user confirmation before deleting a list, warning that all reminders inside will be permanently destroyed.
   - **`delete_reminder`**: Show the reminder title and list name before permanent deletion.
5. **Bulk Modifications**:
   - For bulk operations affecting $\ge 3$ reminders, show the summary and request confirmation.

---

## 🔨 Build & Verification Commands

```bash
# Build debug binary
swift build

# Build optimized release binary
swift build -c release

# Verify MCP protocol handshake via stdio
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"serverInfo":{"name":"test"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n' | .build/release/apple-eventkit-mcp
```
