#!/usr/bin/env bash
set -euo pipefail

REPO="sharat/apple-eventkit-mcp"
BINARY_NAME="apple-eventkit-mcp"
SERVER_KEY="apple-reminders"

# Parse CLI flags
BUILD_SOURCE=false
AUTO_YES=false
SKIP_CHECKSUM=false
INSTALL_SKILL_FLAG=""
INSTALL_CONFIG_FLAG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --build|-b)
      BUILD_SOURCE=true
      shift
      ;;
    --yes|-y|--all)
      AUTO_YES=true
      shift
      ;;
    --skip-checksum|--insecure)
      SKIP_CHECKSUM=true
      shift
      ;;
    --skill)
      INSTALL_SKILL_FLAG="true"
      shift
      ;;
    --no-skill)
      INSTALL_SKILL_FLAG="false"
      shift
      ;;
    --config)
      INSTALL_CONFIG_FLAG="true"
      shift
      ;;
    --no-config)
      INSTALL_CONFIG_FLAG="false"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

check_system_compatibility() {
  local os_name
  os_name=$(uname -s 2>/dev/null || echo "Unknown")
  local arch_name
  arch_name=$(uname -m 2>/dev/null || echo "Unknown")
  local prod_ver="N/A"
  local major_ver=0

  if [ "$os_name" = "Darwin" ]; then
    prod_ver=$(sw_vers -productVersion 2>/dev/null || echo "0")
    major_ver=$(echo "$prod_ver" | cut -d '.' -f 1)
  fi

  local failed=false
  local reason=""

  if [ "$os_name" != "Darwin" ]; then
    failed=true
    reason="Operating system is not macOS (detected: $os_name)."
  elif [ "$arch_name" != "arm64" ] && [ "$arch_name" != "aarch64" ]; then
    failed=true
    reason="Hardware is not Apple Silicon (detected architecture: $arch_name)."
  elif [ "$major_ver" -lt 26 ] 2>/dev/null; then
    failed=true
    reason="macOS version must be Tahoe (26.0) or higher (detected version: $prod_ver)."
  fi

  if [ "$failed" = true ]; then
    echo ""
    echo "================================================="
    echo " ❌ Apple EventKit MCP - Unsupported Platform"
    echo "================================================="
    echo "This skill and MCP server cannot be installed on this platform."
    echo "It requires:"
    echo "  • Hardware: Apple Silicon Mac (M-series / arm64)"
    echo "  • Operating System: macOS 26.0 (Tahoe) or higher"
    echo ""
    echo "Details: $reason"
    echo "================================================="
    echo ""
    exit 1
  fi
}

check_system_compatibility

echo "================================================="
echo " Installing Apple EventKit MCP Server"
echo "================================================="

# Target installation directory resolution
if [ -n "${INSTALL_DIR:-}" ]; then
  TARGET_DIR="$INSTALL_DIR"
elif [ -w "/usr/local/bin" ]; then
  TARGET_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
  TARGET_DIR="$HOME/.local/bin"
else
  TARGET_DIR="/usr/local/bin"
fi

mkdir -p "$TARGET_DIR" 2>/dev/null || true
FULL_BINARY_PATH="${TARGET_DIR}/${BINARY_NAME}"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT HUP INT QUIT TERM

# Prompt helper function (safe across piped and interactive environments)
prompt_user() {
  local prompt_text="$1"
  local default_val="$2"
  local ans=""
  if [ "$AUTO_YES" = true ]; then
    echo "$default_val"
  elif [ -t 0 ]; then
    read -r -p "$prompt_text" ans || ans="$default_val"
    echo "${ans:-$default_val}"
  elif [ -e /dev/tty ] && [ -r /dev/tty ]; then
    # `curl … | bash` from a terminal: stdin is the pipe, but the controlling
    # terminal is still available to prompt on.
    read -r -p "$prompt_text" ans < /dev/tty || ans="$default_val"
    echo "${ans:-$default_val}"
  else
    # No way to ask (CI, Docker, cron). Decline rather than silently consent to
    # installing skill files and rewriting MCP client configs; pass --yes to opt in.
    echo "N"
  fi
}

# Function: Download pre-built universal binary from GitHub Release and verify checksum
install_from_release() {
  echo "==> Fetching latest release info from https://github.com/${REPO}..."
  LATEST_JSON=$(curl -fsSL --connect-timeout 10 -H "User-Agent: curl" "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)

  if [ -z "${LATEST_JSON}" ]; then
    echo "Warning: Could not query latest release from GitHub API."
    return 1
  fi

  DOWNLOAD_URL=$(echo "${LATEST_JSON}" | grep -o 'https://[^" ]*apple-eventkit-mcp-[^" ]*macos-arm64\.tar\.gz' | head -n 1 || true)
  if [ -z "${DOWNLOAD_URL}" ]; then
    DOWNLOAD_URL=$(echo "${LATEST_JSON}" | grep -o 'https://[^" ]*apple-eventkit-mcp-[^" ]*macos-universal\.tar\.gz' | head -n 1 || true)
  fi
  SHASUMS_URL=$(echo "${LATEST_JSON}" | grep -o 'https://[^" ]*SHA256SUMS\.txt' | head -n 1 || true)

  if [ -z "${DOWNLOAD_URL}" ]; then
    echo "Warning: Could not resolve release archive URL."
    return 1
  fi

  echo "==> Downloading Apple Silicon macOS binary from GitHub Releases..."
  if ! curl -fsSL --max-time 60 "${DOWNLOAD_URL}" -o "${TMP_DIR}/archive.tar.gz"; then
    echo "Warning: Failed to download release archive."
    return 1
  fi

  # Mandatory Checksum Verification (Fail-Closed)
  if [ "$SKIP_CHECKSUM" = true ]; then
    echo "    ! Warning: Checksum verification explicitly bypassed via --skip-checksum."
  else
    if [ -z "${SHASUMS_URL}" ]; then
      echo "Error: SHA256SUMS.txt not found in release assets. Aborting for security (use --skip-checksum to override)."
      return 1
    fi

    if ! curl -fsSL --max-time 15 "${SHASUMS_URL}" -o "${TMP_DIR}/SHA256SUMS.txt"; then
      echo "Error: Failed to download SHA256SUMS.txt. Aborting for security."
      return 1
    fi

    ARCHIVE_NAME=$(basename "${DOWNLOAD_URL}")
    EXPECTED_SHA=$(grep -E "[[:space:]]${ARCHIVE_NAME}\$" "${TMP_DIR}/SHA256SUMS.txt" | head -n 1 | awk '{print $1}' || true)
    if [ -z "${EXPECTED_SHA}" ]; then
      echo "Error: Archive ${ARCHIVE_NAME} not listed in SHA256SUMS.txt. Aborting for security."
      return 1
    fi

    ACTUAL_SHA=$(shasum -a 256 "${TMP_DIR}/archive.tar.gz" | awk '{print $1}')
    if [ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]; then
      echo "Error: SHA256 checksum mismatch on downloaded archive!"
      echo "  Expected: ${EXPECTED_SHA}"
      echo "  Actual:   ${ACTUAL_SHA}"
      return 1
    fi
    echo "    ✓ SHA256 checksum verified (${ACTUAL_SHA:0:16}...)"
  fi

  echo "==> Extracting binary and assets..."
  tar -xzf "${TMP_DIR}/archive.tar.gz" -C "${TMP_DIR}"

  echo "==> Installing ${BINARY_NAME} to ${FULL_BINARY_PATH}..."
  if [ -w "${TARGET_DIR}" ]; then
    install -m 755 "${TMP_DIR}/${BINARY_NAME}" "${FULL_BINARY_PATH}"
    xattr -cr "${FULL_BINARY_PATH}" 2>/dev/null || true
    codesign --force -s - "${FULL_BINARY_PATH}" 2>/dev/null || true
  else
    sudo install -m 755 "${TMP_DIR}/${BINARY_NAME}" "${FULL_BINARY_PATH}"
    sudo xattr -cr "${FULL_BINARY_PATH}" 2>/dev/null || true
    sudo codesign --force -s - "${FULL_BINARY_PATH}" 2>/dev/null || true
  fi

  return 0
}

# Function: Build from source in isolated directory
build_from_source() {
  if ! command -v swift >/dev/null 2>&1; then
    echo "Error: Swift compiler not found. Please install Xcode Command Line Tools (xcode-select --install)."
    exit 1
  fi

  local BUILD_DIR="${TMP_DIR}/source"
  # Only use current directory if explicitly requested via --build AND in a valid repo checkout
  if [ "$BUILD_SOURCE" = true ] && [ -f "Package.swift" ] && [ -d "Sources/AppleEventKitMCPCore" ]; then
    BUILD_DIR="."
  else
    echo "==> Cloning source repository into sandboxed build directory..."
    git clone --depth 1 "https://github.com/${REPO}.git" "$BUILD_DIR"
  fi

  echo "==> Building from source with Swift..."
  (
    cd "$BUILD_DIR"
    DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build -c release || swift build -c release
  )

  local BUILT_BINARY="${BUILD_DIR}/.build/release/${BINARY_NAME}"
  if [ ! -f "$BUILT_BINARY" ]; then
    echo "Error: Built binary not found at $BUILT_BINARY."
    exit 1
  fi

  echo "==> Installing binary to ${FULL_BINARY_PATH}..."
  if [ -w "${TARGET_DIR}" ]; then
    install -m 755 "$BUILT_BINARY" "${FULL_BINARY_PATH}"
    xattr -cr "${FULL_BINARY_PATH}" 2>/dev/null || true
    codesign --force -s - "${FULL_BINARY_PATH}" 2>/dev/null || true
  else
    sudo install -m 755 "$BUILT_BINARY" "${FULL_BINARY_PATH}"
    sudo xattr -cr "${FULL_BINARY_PATH}" 2>/dev/null || true
    sudo codesign --force -s - "${FULL_BINARY_PATH}" 2>/dev/null || true
  fi
}

# Function: Install Agent Skill from verified archive or clone
install_agent_skill() {
  local SKILL_DEST="$HOME/.gemini/skills/apple-reminders"
  local AGENTS_SKILL_DEST="$HOME/.agents/skills/apple-reminders"
  echo "==> Installing Apple Reminders Agent Skill to ${SKILL_DEST}..."
  mkdir -p "${SKILL_DEST}"
  mkdir -p "${AGENTS_SKILL_DEST}" 2>/dev/null || true

  if [ -d "${TMP_DIR}/skills/apple-reminders" ]; then
    cp -Rf "${TMP_DIR}/skills/apple-reminders/"* "${SKILL_DEST}/"
    cp -Rf "${TMP_DIR}/skills/apple-reminders/"* "${AGENTS_SKILL_DEST}/" 2>/dev/null || true
  elif [ -d "${TMP_DIR}/source/skills/apple-reminders" ]; then
    cp -Rf "${TMP_DIR}/source/skills/apple-reminders/"* "${SKILL_DEST}/"
    cp -Rf "${TMP_DIR}/source/skills/apple-reminders/"* "${AGENTS_SKILL_DEST}/" 2>/dev/null || true
  else
    mkdir -p "${SKILL_DEST}/references"
    curl -fsSL --connect-timeout 10 "https://raw.githubusercontent.com/${REPO}/main/skills/apple-reminders/SKILL.md" -o "${SKILL_DEST}/SKILL.md"
    curl -fsSL --connect-timeout 10 "https://raw.githubusercontent.com/${REPO}/main/skills/apple-reminders/references/tools.md" -o "${SKILL_DEST}/references/tools.md"
  fi

  echo "    ✓ Skill installed to ${SKILL_DEST}"
}

# Function: Configure MCP client JSON files safely and atomically
update_json_mcp_config() {
  local CONFIG_PATH="$1"
  python3 - "$CONFIG_PATH" "$SERVER_KEY" "$FULL_BINARY_PATH" << 'EOF'
import json, os, sys, time, shutil

config_path = os.path.expanduser(sys.argv[1])
server_name = sys.argv[2]
binary_path = sys.argv[3]

os.makedirs(os.path.dirname(config_path), exist_ok=True)
data = {}

if os.path.exists(config_path):
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        # Create timestamped backup before touching unparseable configs
        timestamp = int(time.time())
        bak_path = f"{config_path}.{timestamp}.bak"
        shutil.copy2(config_path, bak_path)
        print(f"    ! Warning: Config file at {config_path} was not valid JSON ({e}).")
        print(f"    ! Backed up existing config to {bak_path}")
        data = {}

if not isinstance(data, dict):
    data = {}

if 'mcpServers' not in data or not isinstance(data['mcpServers'], dict):
    data['mcpServers'] = {}

data['mcpServers'][server_name] = {'command': binary_path}

# Atomic write via temp file + replace
temp_path = f"{config_path}.tmp.{os.getpid()}"
with open(temp_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

os.replace(temp_path, config_path)
EOF
}

# Function: Configure all detected MCP clients
configure_mcp_clients() {
  echo "==> Configuring MCP clients..."

  # 1. Claude Desktop (if installed or directory exists)
  local CLAUDE_DIR="$HOME/Library/Application Support/Claude"
  local CLAUDE_APP="/Applications/Claude.app"
  if [ -d "$CLAUDE_DIR" ] || [ -d "$CLAUDE_APP" ]; then
    local CLAUDE_CONFIG="${CLAUDE_DIR}/claude_desktop_config.json"
    update_json_mcp_config "$CLAUDE_CONFIG"
    echo "    ✓ Claude Desktop configured ($CLAUDE_CONFIG)"
  fi

  # 2. Google Antigravity / Gemini CLI
  local AGY_DIR="$HOME/.gemini"
  if [ -d "$AGY_DIR" ]; then
    local AGY_CONFIG="${AGY_DIR}/config/mcp_config.json"
    update_json_mcp_config "$AGY_CONFIG"
    echo "    ✓ Antigravity configured ($AGY_CONFIG)"
  fi

  # 3. Claude CLI (Claude Code)
  if command -v claude >/dev/null 2>&1; then
    if claude mcp add --scope user "$SERVER_KEY" "$FULL_BINARY_PATH" >/dev/null 2>&1 || claude mcp add "$SERVER_KEY" "$FULL_BINARY_PATH" >/dev/null 2>&1; then
      echo "    ✓ Claude CLI (Claude Code) configured (--scope user)"
    else
      echo "    ! Claude CLI detected; run: claude mcp add --scope user ${SERVER_KEY} ${FULL_BINARY_PATH}"
    fi
  fi
}

# Step 1: Install Binary
if [ "$BUILD_SOURCE" = true ]; then
  build_from_source
else
  if ! install_from_release; then
    echo "==> Pre-built binary download unavailable. Falling back to building from source..."
    build_from_source
  fi
fi

# Step 2: Handle Skill Installation
SHOULD_INSTALL_SKILL=true
if [ "$INSTALL_SKILL_FLAG" = "false" ]; then
  SHOULD_INSTALL_SKILL=false
elif [ "$INSTALL_SKILL_FLAG" = "true" ] || [ "$AUTO_YES" = true ]; then
  SHOULD_INSTALL_SKILL=true
else
  echo ""
  resp=$(prompt_user "==> Install the Apple Reminders AI Agent Skill (~/.gemini/skills)? [Y/n] " "Y")
  if [[ "$resp" =~ ^([nN][oO]|[nN])$ ]]; then
    SHOULD_INSTALL_SKILL=false
  fi
fi

if [ "$SHOULD_INSTALL_SKILL" = true ]; then
  install_agent_skill
else
  echo "==> Skipped agent skill installation."
fi

# Step 3: Handle MCP Clients Configuration
SHOULD_CONFIGURE_MCP=true
if [ "$INSTALL_CONFIG_FLAG" = "false" ]; then
  SHOULD_CONFIGURE_MCP=false
elif [ "$INSTALL_CONFIG_FLAG" = "true" ] || [ "$AUTO_YES" = true ]; then
  SHOULD_CONFIGURE_MCP=true
else
  echo ""
  resp=$(prompt_user "==> Automatically configure MCP clients (Claude Desktop, Antigravity, Claude Code)? [Y/n] " "Y")
  if [[ "$resp" =~ ^([nN][oO]|[nN])$ ]]; then
    SHOULD_CONFIGURE_MCP=false
  fi
fi

if [ "$SHOULD_CONFIGURE_MCP" = true ]; then
  configure_mcp_clients
else
  echo "==> Skipped MCP client configuration."
fi

echo ""
echo "================================================="
echo " ✨ Installation & Configuration Complete!"
echo "================================================="
echo "   Binary:   ${FULL_BINARY_PATH}"
if [ "$SHOULD_INSTALL_SKILL" = true ]; then
  echo "   Skill:    $HOME/.gemini/skills/apple-reminders"
fi
echo ""
echo "👉 Next steps:"
echo "   - Restart Claude Desktop (Cmd + Q and reopen)"
echo "   - On first prompt, grant macOS Reminders permission"
echo ""
