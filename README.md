# Apple EventKit MCP Server

A high-performance, native macOS Model Context Protocol (MCP) server for Apple Reminders and EventKit written entirely in Swift.

It connects LLM agents and clients directly to macOS EventKit using Apple's native frameworks—with zero Node.js, Python, or wrapper dependencies.

---

## ✨ Highlights

- **Native & Ultra-Fast**: Built in Swift with direct in-memory `EKEventStore` integration.
- **Self-Contained**: Produces a single lightweight standalone binary (~480 KB).
- **Full CRUD Support**: Manage individual reminders, alarms, priorities, notes, URLs, due dates, and reminder lists.
- **Includes AI Agent Skill**: Comes with a bundled `apple-reminders` skill providing scheduling, triage, and best practices for AI agents.

> [!NOTE]
> **System Compatibility**: Supported on **macOS 26.0 (Tahoe) or higher**, Apple Silicon (`arm64`).
>
> **Prompt Safety Notice**: Destructive operations (such as deleting lists or deleting reminders) permanently remove data. The server and skill require explicit confirmation before deleting.

> [!NOTE]
> **Current Scope**: This server currently supports **Apple Reminders** (tasks, to-dos, alarms, priorities, and lists) only. It does not support Calendar events yet.

---

## 🛠️ Available MCP Tools

| Tool | Description |
| :--- | :--- |
| `list_reminders` | Query reminders with filtering by list name/ID, completion status, due dates (`due_after`, `due_before`), search query, and limit. |
| `create_reminder` | Create a new reminder with title, notes, due date (ISO 8601), list name/ID, priority (`none`, `low`, `medium`, `high`), and URL. |
| `update_reminder` | Update an existing reminder (title, notes, list, due date, clear due date, priority, completion status, URL). |
| `complete_reminder` | Mark a reminder as completed (`true`) or uncompleted (`false`) by ID. |
| `delete_reminder` | Permanently delete a reminder by ID. |
| `list_reminder_lists` | List all reminder lists/categories with their names, IDs, and colors. |
| `create_reminder_list` | Create a new reminder list with a title and optional hex color. |
| `delete_reminder_list` | Delete an entire reminder list and all reminders inside it. |

---

## 📦 Installation

### Option 1: Via `skills.sh` (Preferred)
The easiest way to install and activate Apple Reminders for your AI agents (Claude Code, Antigravity, Cursor, etc.):

```bash
# Install globally for all AI sessions (Recommended)
npx skills add sharat/apple-eventkit-mcp -g

# Or install to your current workspace
npx skills add sharat/apple-eventkit-mcp
```

---

### Option 2: Standalone Shell Installer
Installs the pre-compiled native binary, configures MCP client config files (Claude Desktop, Antigravity, Claude Code), and sets up the skill:

```bash
curl -fsSL https://raw.githubusercontent.com/sharat/apple-eventkit-mcp/main/install.sh | bash
```

---

### Option 3: Build & Install from Source
Requires Swift 5.9+ / Xcode Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/sharat/apple-eventkit-mcp.git
cd apple-eventkit-mcp

# Build and install to /usr/local/bin
sudo make install
```

---

### Option 4: Manual Download
Download the pre-compiled Apple Silicon (`arm64`) macOS binary archive from [GitHub Releases](https://github.com/sharat/apple-eventkit-mcp/releases/latest), extract `apple-eventkit-mcp`, and move it to `/usr/local/bin` or `~/.local/bin`.

---

## 🔌 Client Setup & Configuration

### 1. Claude Desktop
Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "apple-reminders": {
      "command": "/usr/local/bin/apple-eventkit-mcp"
    }
  }
}
```
*(If installed to `~/.local/bin`, use `"/Users/<username>/.local/bin/apple-eventkit-mcp"`).*

Restart Claude Desktop (`Cmd + Q` and re-open) to activate.

---

### 2. Claude CLI (Claude Code)
Add the server globally for your user profile:

```bash
claude mcp add --scope user apple-reminders /usr/local/bin/apple-eventkit-mcp
```

---

### 3. Google Antigravity
Add the server to your global config (`~/.gemini/config/mcp_config.json`) or workspace configuration:

```json
{
  "mcpServers": {
    "apple-reminders": {
      "command": "apple-eventkit-mcp"
    }
  }
}
```

To also enable the intelligent **Apple Reminders Agent Skill**:
```bash
# Install to workspace:
mkdir -p .agents/skills
cp -r skills/apple-reminders .agents/skills/

# Or install globally for all Antigravity sessions:
mkdir -p ~/.gemini/skills
cp -r skills/apple-reminders ~/.gemini/skills/
```

---

### 4. Codex (OpenAI Codex / Codex CLI)
Add to your `codex_config.json` or MCP settings:

```json
{
  "mcpServers": {
    "apple-reminders": {
      "command": "apple-eventkit-mcp"
    }
  }
}
```

---

### 5. Hermes Agent
Add to your `hermes_config.json` or `config.yaml`:

**JSON format:**
```json
{
  "mcpServers": {
    "apple-reminders": {
      "command": "apple-eventkit-mcp"
    }
  }
}
```

**YAML format:**
```yaml
mcp_servers:
  apple-reminders:
    command: apple-eventkit-mcp
```

---

### 6. OpenCode (OpenCode Interpreter)
Add to `~/.config/opencode/config.json` or project-level `opencode.json`:

```json
{
  "mcp": {
    "servers": {
      "apple-reminders": {
        "command": "apple-eventkit-mcp"
      }
    }
  }
}
```

---

### 7. Cursor / Windsurf / Zed
Add to your IDE's MCP configuration settings:

```json
{
  "mcpServers": {
    "apple-reminders": {
      "command": "apple-eventkit-mcp"
    }
  }
}
```

---

## 🧠 Bundled AI Skill (skills.sh / agentskills.io standard)

This repository includes a compliant Agent Skill in [`skills/apple-reminders/SKILL.md`](skills/apple-reminders/SKILL.md) following the [skills.sh](https://skills.sh) / [Agent Skills](https://agentskills.io) specification.

### Install via skills.sh CLI:
```bash
# Install to current project / workspace
npx skills add sharat/apple-eventkit-mcp

# Or install globally for all AI agent sessions
npx skills add sharat/apple-eventkit-mcp -g
```

### What it equips AI assistants with:
- **Date & Time Anchoring**: Resolves natural language expressions (*"tomorrow at 5 PM"*, *"next Monday morning"*) to precise ISO 8601 timestamps using local timezones.
- **Active Task Scoping**: Always targets pending tasks during updates/rescheduling so completed tasks are never unintentionally revived.
- **Duplicate Prevention**: Checks existing reminders before creating new entries.
- **Contextual Routing**: Automatically routes tasks to matching lists (e.g. Groceries $\rightarrow$ `Shopping`, Bills $\rightarrow$ `Finance`, Project tasks $\rightarrow$ `Work`).
- **Safety First**: Strictly prevents accidental deletion and requires confirmation before destructive actions.
- **Clean Presentation**: Formats checklists with priority badges and due dates.

---

## 🔒 macOS Permissions (TCC)

On the first tool execution, macOS will prompt you to grant access to Reminders:
1. Click **Allow** / **Full Access** when prompted.
2. If permissions need to be checked or adjusted later, go to:
   `System Settings > Privacy & Security > Reminders`.

---

## 💡 Example Queries

- *"What reminders do I have due today?"*
- *"Add a high-priority reminder 'Prepare tax filing' due tomorrow at 4 PM."*
- *"Show all incomplete reminders in my 'Work' list."*
- *"Mark 'Buy groceries' as completed."*
- *"Create a new list called 'Trip to Japan' with color #0088FF."*

---

## 📄 License

MIT License. Free for personal and commercial use.
