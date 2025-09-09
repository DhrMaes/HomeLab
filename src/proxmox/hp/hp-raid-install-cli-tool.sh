#!/bin/bash
# hp-raid-install-cli-tool – Set up HPE MCP repo and install ssacli on Proxmox/Debian

set -euo pipefail

echo "=== Checking if ssacli is already installed ==="
if command -v ssacli &>/dev/null; then
  echo "ssacli is already installed. Skipping installation."
  exit 0
fi

echo "=== Adding HPE MCP repository for Debian Bookworm (Proxmox 8.x) ==="
REPO_FILE="/etc/apt/sources.list.d/hp-mcp.list"
if ! grep -q "^deb .*downloads.linux.hpe.com/SDR/repo/mcp.*bookworm/current" "$REPO_FILE" 2>/dev/null; then
  echo "deb https://downloads.linux.hpe.com/SDR/repo/mcp bookworm/current non-free" \
    | tee "$REPO_FILE"
else
  echo "Repository already present: $REPO_FILE"
fi

echo "=== Adding HPE GPG keys ==="
add_key_if_missing() {
  local url="$1"
  local fingerprint
  fingerprint=$(curl -fsSL "$url" | gpg --with-fingerprint --with-colons 2>/dev/null | awk -F: '/^fpr:/ {print $10; exit}')

  if apt-key finger | grep -q "$fingerprint"; then
    echo "Key already installed: $fingerprint"
  else
    curl -fsSL "$url" | apt-key add -
    echo "Added key: $fingerprint"
  fi
}

add_key_if_missing "https://downloads.linux.hpe.com/SDR/hpPublicKey2048_key1.pub"
add_key_if_missing "https://downloads.linux.hpe.com/SDR/hpePublicKey2048_key1.pub"
add_key_if_missing "https://downloads.linux.hpe.com/SDR/hpePublicKey2048_key2.pub"

echo "=== Updating APT and installing ssacli ==="
apt update
apt install -y ssacli

echo "=== Done! Test with: ssacli ctrl all show status ==="
