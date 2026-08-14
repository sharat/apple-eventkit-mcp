#!/usr/bin/env bash
#
# MCP stdio protocol conformance check.
#
# Asserts only what unit tests structurally cannot reach: that the real binary
# speaks newline-delimited JSON on stdout, one response per request, and exits
# cleanly. Response *semantics* are owned by MCPServerProtocolTests — do not
# duplicate those assertions here.
#
# Usage: scripts/protocol-conformance.sh [path-to-binary]
#        (defaults to .build/release/apple-eventkit-mcp)

set -euo pipefail

BIN="${1:-.build/release/apple-eventkit-mcp}"

if [ ! -x "$BIN" ]; then
  echo "error: binary not found or not executable: $BIN" >&2
  echo "hint: run 'swift build -c release' first" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

printf '%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | "$BIN" 2>/dev/null > "$WORK_DIR/handshake.jsonl"

printf 'not json\n' | "$BIN" 2>/dev/null > "$WORK_DIR/parse-error.jsonl"

WORK_DIR="$WORK_DIR" python3 <<'PY'
import json
import os

work = os.environ["WORK_DIR"]

lines = [l for l in open(f"{work}/handshake.jsonl") if l.strip()]
assert len(lines) == 2, f"expected one response line per request, got {len(lines)}"
init, tools = (json.loads(l) for l in lines)

# Guards the stringified-struct regression: result must be a JSON object, never
# a Swift debug description rendered into a string.
for name, msg in (("initialize", init), ("tools/list", tools)):
    result = msg.get("result")
    assert isinstance(result, dict), \
        f"{name} result must be an object, got {type(result).__name__}: {result!r:.120}"

assert init["result"]["protocolVersion"] == "2025-06-18", \
    f"client protocolVersion not echoed: {init['result']['protocolVersion']}"
assert len(tools["result"]["tools"]) == 8, \
    f"expected 8 tools, got {len(tools['result']['tools'])}"

err = json.loads(open(f"{work}/parse-error.jsonl").read())
assert "id" in err and err["id"] is None, f"parse error must carry an explicit null id: {err}"
assert err["error"]["code"] == -32700, err

print("  ✓ stdio framing, structured results, and null-id parse error")
PY

# Out-of-range numerics must not trap the process (a Swift trap exits non-zero,
# which `set -e` turns into a failure here).
printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_reminders","arguments":{"limit":1e30}}}\n' \
  | "$BIN" > /dev/null 2>&1
echo "  ✓ out-of-range numerics do not trap"

echo "MCP protocol conformance OK"
