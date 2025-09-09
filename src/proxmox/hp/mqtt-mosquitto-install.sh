#!/bin/bash
# mqtt-mosquitto-install.sh – Install mosquitto-clients on Proxmox/Debian

set -euo pipefail

echo "=== Checking if mosquitto-clients is already installed ==="
if dpkg -s mosquitto-clients &>/dev/null; then
  echo "mosquitto-clients is already installed. Skipping installation."
  exit 0
fi

echo "=== Updating APT and installing mosquitto-clients ==="
apt update
apt install -y mosquitto-clients

echo "=== Done! ==="
