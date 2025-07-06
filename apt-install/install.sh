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

# Install only selected Kali metapackages
echo "[*] Installing selected Kali Linux metapackages..."
sudo apt install -y \
    kali-linux-labs \
    kali-tools-windows-resources \
    kali-tools-reporting \
    kali-tools-post-exploitation \
    kali-tools-reverse-engineering \
    kali-tools-web \
    kali-tools-database \
    kali-tools-forensics \
    kali-tools-crypto-stego \
    kali-tools-exploitation

echo "[✓] Selected Kali tools installed."

# Cleanup
echo "[*] Cleaning up..."
sudo apt autoremove -y
sudo apt clean
echo "[✓] System cleanup completed."

echo "[✓] All tasks completed successfully!"
