#!/bin/bash
set -euo pipefail

echo "[*] Updating package list and upgrading system..."
sudo apt update && sudo apt full-upgrade -y

# Install or Upgrade Google Chrome
echo "[*] Installing or upgrading Google Chrome..."
if wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb; then
    sudo apt install -y /tmp/chrome.deb || sudo apt install -f -y
    rm -f /tmp/chrome.deb
    echo "[✓] Google Chrome installed or upgraded."
else
    echo "[✗] Failed to download Chrome. Check your internet or URL."
    exit 1
fi

# Install Kali Metapackage (with suggested & recommended packages)
echo "[*] Installing all Kali Linux metapackages with suggestions and recommendations..."
sudo apt install -y --install-recommends --install-suggests kali-linux-everything
echo "[✓] Kali tools (full) installed."

# Cleanup
echo "[*] Cleaning up..."
sudo apt autoremove -y
sudo apt clean
echo "[✓] System cleanup completed."

echo "[✓] All tasks completed successfully!"
# Exit script
