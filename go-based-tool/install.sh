#!/bin/bash

# ─────────────────────────────────────────────────────
# GO-BASED TOOLS INSTALLER (Hardened)
# Author: Sachin Nishad
# Installs tools to: ~/bin
# ─────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_FILE="$SCRIPT_DIR/tools/tools.txt"
TOOLS_DIR="$HOME/bin"
TEMP_GOPATH="/tmp/go-installer-build"
LOGFILE="/tmp/install.log"

# Redirect all stdout/stderr to logfile
exec > >(tee -a "$LOGFILE") 2>&1

echo "─────────────── GO TOOL INSTALLER ───────────────"
echo "[*] Script location     : $SCRIPT_DIR"
echo "[*] Tool list file      : $TOOL_FILE"
echo "[*] Install target path : $TOOLS_DIR"
echo "[*] Log file            : $LOGFILE"
echo

# ─────────────────────────────────────────────────────
# Step 1: Validate Tool List File
# ─────────────────────────────────────────────────────
if [[ ! -f "$TOOL_FILE" ]]; then
  echo "[!] ERROR: Tool list file not found at: $TOOL_FILE"
  exit 1
fi

# ─────────────────────────────────────────────────────
# Step 2: Install Dependencies (Go, Git, etc.)
# ─────────────────────────────────────────────────────
echo "[*] Checking required APT packages..."

REQUIRED_PKGS=(git curl wget golang)

for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    echo "[+] Installing missing package: $pkg"
    sudo apt-get update && sudo apt-get install -y "$pkg"
  else
    echo "[✓] $pkg is already installed."
  fi
done

# ─────────────────────────────────────────────────────
# Step 3: Setup Environment
# ─────────────────────────────────────────────────────
mkdir -p "$TOOLS_DIR"
mkdir -p "$TEMP_GOPATH/bin"
export GOPATH="$TEMP_GOPATH"
export PATH="$PATH:$GOPATH/bin"

# ─────────────────────────────────────────────────────
# Step 4: Install Tools
# ─────────────────────────────────────────────────────
echo
echo "[*] Installing tools from go-tools.txt..."

mapfile -t LINKS < <(grep -vE '^\s*#|^\s*$' "$TOOL_FILE")

for tool in "${LINKS[@]}"; do
  echo "→ Installing: $tool"
  
  if go install "$tool@latest"; then
    echo "   ↳ go install succeeded."

    # Find newly created binary (any file inside $GOPATH/bin after install)
    latest_bin=$(find "$GOPATH/bin" -type f -executable -printf "%T@ %p\n" | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -n "$latest_bin" && -f "$latest_bin" ]]; then
      bin_name=$(basename "$latest_bin")
      mv -f "$latest_bin" "$TOOLS_DIR/$bin_name"
      chmod +x "$TOOLS_DIR/$bin_name"
      echo "   ↳ Installed to: $TOOLS_DIR/$bin_name"
    else
      echo "   ✗ ERROR: No binary found after install."
    fi
  else
    echo "   ✗ ERROR: go install failed for $tool"
  fi
done

# ─────────────────────────────────────────────────────
# Step 5: Add ~/bin to PATH if needed
# ─────────────────────────────────────────────────────
if ! echo "$PATH" | grep -q "$HOME/bin"; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
  echo "[+] Added ~/bin to PATH in .bashrc"
  export PATH="$HOME/bin:$PATH"
fi

# ─────────────────────────────────────────────────────
# Step 6: Cleanup
# ─────────────────────────────────────────────────────
echo
echo "[*] Cleaning temporary build directory..."
rm -rf "$TEMP_GOPATH"

echo
echo "[✓] All tools installed successfully to $TOOLS_DIR."
echo "    Please restart your terminal or run: source ~/.bashrc"
