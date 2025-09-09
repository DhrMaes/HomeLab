#!/bin/bash
# hp-raid-status-install.sh – bootstrap HP RAID → MQTT monitor on Proxmox

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing mosquitto-clients ==="
bash "$SCRIPT_DIR/src/proxmox/hp/mqtt-mosquitto-install.sh"

echo "=== Installing ssacli tool ==="
bash "$SCRIPT_DIR/src/proxmox/hp/hp-raid-install-cli-tool.sh"

echo "=== Installing RAID status publisher script ==="
install -m 0755 "$SCRIPT_DIR/src/proxmox/hp/hp-raid-status-push-mqtt.sh" /usr/local/bin/hp-raid-status-push-mqtt.sh

echo "=== Installing systemd service and timer ==="
install -m 0644 "$SCRIPT_DIR/src/proxmox/hp/hp-raid-status-push-mqtt.service" /etc/systemd/system/hp-raid-status-push-mqtt.service
install -m 0644 "$SCRIPT_DIR/src/proxmox/hp/hp-raid-status-push-mqtt.timer" /etc/systemd/system/hp-raid-status-push-mqtt.timer

echo "=== Gathering MQTT credentials ==="
read -rp "MQTT Broker IP/Hostname: " MQTT_BROKER
read -rp "MQTT Port [1883]: " MQTT_PORT
MQTT_PORT=${MQTT_PORT:-1883}
read -rp "MQTT Username: " MQTT_USER
read -rsp "MQTT Password: " MQTT_PASS
echo

ENV_FILE="/etc/default/hp-raid-mqtt"
echo "=== Writing $ENV_FILE ==="
cat <<EOF | sudo tee "$ENV_FILE" > /dev/null
MQTT_BROKER="$MQTT_BROKER"
MQTT_PORT="$MQTT_PORT"
MQTT_USER="$MQTT_USER"
MQTT_PASS="$MQTT_PASS"
EOF
chmod 600 "$ENV_FILE"

echo "=== Enabling and starting systemd timer ==="
systemctl daemon-reexec
systemctl enable --now hp-raid-status-push-mqtt.timer

echo "=== Setup complete! ==="
echo "- RAID status will now be pushed to MQTT on schedule"
echo "- You can check logs with: journalctl -u hp-raid-status-push-mqtt.service"
echo "- Or trigger a manual run with: systemctl start hp-raid-status-push-mqtt.service"
