#!/usr/bin/env bash
set -euo pipefail

# System requirements validation
os_name=$(uname -s 2>/dev/null || echo "Unknown")
arch_name=$(uname -m 2>/dev/null || echo "Unknown")
prod_ver="N/A"
major_ver=0

if [ "$os_name" = "Darwin" ]; then
  prod_ver=$(sw_vers -productVersion 2>/dev/null || echo "0")
  major_ver=$(echo "$prod_ver" | cut -d '.' -f 1)
fi

failed=false
reason=""

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

echo "==> System compatibility check passed (macOS ${prod_ver})."
echo "==> Running installer with automatic setup..."
curl -fsSL https://raw.githubusercontent.com/sharat/apple-eventkit-mcp/main/install.sh | bash -s -- --yes
