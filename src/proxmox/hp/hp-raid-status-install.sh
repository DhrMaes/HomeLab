#!/bin/bash
# install-hpraid-monitor.sh – self-contained installer for HP RAID → MQTT monitor
# Downloads only required files from GitHub raw URLs, supports version-specific install

set -euo pipefail

# --- CONFIG ---
GITHUB_USER="DhrMaes"
REPO="HomeLab"
VERSION="${1:-main}"  # default to main if not specified
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_USER/$REPO/refs/heads/$VERSION/src/proxmox"

echo "Installing version: $VERSION"

# --- TEMP DIR ---
TMPDIR=$(mktemp -d)

# --- Helper ---
download_file() {
    local url="$1"
    local dest="$2"
    echo "Downloading $url -> $dest"
    wget -qO "$dest" "$url"
    chmod +x "$dest" || true
}

# --- Download required files ---
download_file "$RAW_BASE/hp/mqtt-mosquitto-install.sh" "$TMPDIR/mqtt-mosquitto-install.sh"
download_file "$RAW_BASE/hp/hp-raid-install-cli-tool.sh" "$TMPDIR/hp-raid-install-cli-tool.sh"
download_file "$RAW_BASE/hp/hp-raid-status-push-mqtt.sh" "/usr/local/bin/hp-raid-status-push-mqtt.sh"
download_file "$RAW_BASE/hp/hp-raid-status-push-mqtt.service" "/etc/systemd/system/hp-raid-status-push-mqtt.service"
download_file "$RAW_BASE/hp/hp-raid-status-push-mqtt.timer" "/etc/systemd/system/hp-raid-status-push-mqtt.timer"

# --- Run installers ---
echo "=== Installing mosquitto-clients ==="
bash "$TMPDIR/mqtt-mosquitto-install.sh"

echo "=== Installing ssacli tool ==="
bash "$TMPDIR/hp-raid-install-cli-tool.sh"

# --- Gather MQTT credentials ---
echo "=== Gather MQTT credentials ==="
read -rp "MQTT Broker IP/Hostname: " MQTT_BROKER
read -rp "MQTT Port [1883]: " MQTT_PORT
MQTT_PORT=${MQTT_PORT:-1883}
read -rp "MQTT Username: " MQTT_USER
read -rsp "MQTT Password: " MQTT_PASS
echo

# --- Create environment file ---
ENV_FILE="/etc/default/hpraid-mqtt"
echo "=== Writing $ENV_FILE ==="
cat <<EOF | tee "$ENV_FILE" > /dev/null
MQTT_BROKER="$MQTT_BROKER"
MQTT_PORT="$MQTT_PORT"
MQTT_USER="$MQTT_USER"
MQTT_PASS="$MQTT_PASS"
EOF
chmod 600 "$ENV_FILE"

# --- Enable and start systemd timer ---
echo "=== Enabling and starting systemd timer ==="
systemctl daemon-reload
systemctl enable --now hp-raid-status-push-mqtt.timer

# --- Cleanup ---
rm -rf "$TMPDIR"

echo "=== Setup complete! ==="
echo "- RAID status will now be pushed to MQTT on schedule"
echo "- Check logs: journalctl -u hp-raid-status-push-mqtt.service"
echo "- Manual run: systemctl start hp-raid-status-push-mqtt.service"
