#!/bin/bash
# hpraid_mqtt.sh – Publish HP Smart Array RAID health to MQTT with HA Discovery
# Uses environment variables for MQTT connection (safe for GitHub)

set -euo pipefail

# Require essential environment variables
: "${MQTT_BROKER:?Need to set MQTT_BROKER}"
: "${MQTT_PORT:=1883}"           # default if not set
: "${MQTT_USER:?Need to set MQTT_USER}"
: "${MQTT_PASS:?Need to set MQTT_PASS}"

HOSTNAME=$(hostname)
BASE_TOPIC="homeassistant/sensor/${HOSTNAME}_raid"

# Device info (groups all sensors in one HA device)
DEVICE_INFO="\"identifiers\": [\"${HOSTNAME}_raid\"], \"name\": \"${HOSTNAME} RAID\", \"manufacturer\": \"HPE\", \"model\": \"ProLiant DL360\""

# --- Functions ---

normalize_status() {
  case "$1" in
    OK) echo "healthy";;
    "Predictive Failure") echo "warning";;
    Failed) echo "failed";;
    Rebuilding) echo "rebuilding";;
    Offline) echo "offline";;
    *) echo "unknown";;
  esac
}

icon_for_status() {
  case "$1" in
    healthy) echo "mdi:check-circle";;
    warning) echo "mdi:alert";;
    failed) echo "mdi:close-circle";;
    rebuilding) echo "mdi:progress-wrench";;
    offline) echo "mdi:harddisk-remove";;
    *) echo "mdi:help-circle";;
  esac
}

publish_mqtt() {
  mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
    -u "$MQTT_USER" -P "$MQTT_PASS" \
    -t "$1" -m "$2"
}

# --- Overall RAID health ---
CTRL_STATUS=$(ssacli ctrl all show status | awk -F ':' '/Controller Status/ {print $2}' | xargs)
LD_STATUS=$(ssacli ctrl all show status | awk -F ':' '/Logical Drive Status/ {print $2}' | xargs)

# if [[ "$CTRL_STATUS" == "OK" && "$LD_STATUS" == "OK" ]]; then
if [[ "$CTRL_STATUS" == "OK" ]]; then
  OVERALL="healthy"
else
  OVERALL="warning"
fi

ICON=$(icon_for_status "$OVERALL")

publish_mqtt "$BASE_TOPIC/overall/config" "{
  \"name\": \"${HOSTNAME} RAID Overall\",
  \"state_topic\": \"$BASE_TOPIC/overall/state\",
  \"unique_id\": \"${HOSTNAME}_raid_overall\",
  \"icon\": \"$ICON\",
  \"device\": { $DEVICE_INFO }
}"
publish_mqtt "$BASE_TOPIC/overall/state" "$OVERALL"

# --- Per-disk status ---
mapfile -t DISKS < <(ssacli ctrl all show config | grep physicaldrive)

for line in "${DISKS[@]}"; do
# ssacli ctrl all show config | grep physicaldrive | while read -r line; do
    DRIVE=$(echo "$line" | awk '{print $2}' | tr -d '()')
    DRIVE_SAFE=$(echo "$DRIVE" | tr ':.' '_')
    RAW_STATUS=$(echo "$line" | awk -F '[()]' '{print $2}' | awk -F',' '{gsub(/^[ \t]+|[ \t]+$/,"",$NF); print $NF}')
    STATUS=$(normalize_status "$RAW_STATUS")
    ICON=$(icon_for_status "$STATUS")

    CONFIG_TOPIC="$BASE_TOPIC/$DRIVE_SAFE/config"
    STATE_TOPIC="$BASE_TOPIC/$DRIVE_SAFE/state"

    publish_mqtt "$CONFIG_TOPIC" "{
      \"name\": \"${HOSTNAME} RAID $DRIVE_SAFE\",
      \"state_topic\": \"$STATE_TOPIC\",
      \"unique_id\": \"${HOSTNAME}_raid_$DRIVE_SAFE\",
      \"icon\": \"$ICON\",
      \"device\": { $DEVICE_INFO }
    }"
    publish_mqtt "$STATE_TOPIC" "$STATUS"
done
