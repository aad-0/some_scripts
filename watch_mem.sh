#!/usr/bin/env bash

# Check every 10 seconds
INTERVAL=1
# 6 GiB threshold in Megabytes
THRESHOLD_MB=8000

echo "Monitoring available memory. Threshold: ${THRESHOLD_MB}MB..."

while true; do
    # Extract column 7 (Available RAM in MB) from 'free -m'
    AVAILABLE_MEM=$(free -m | awk '/^Mem:/ {print $4}')
    echo "AVAIL ${AVAILABLE_MEM}"
    for zone in /sys/class/thermal/thermal_zone*/; do
        type=$(cat "${zone}type")
        temp=$(cat "${zone}temp")
        echo "$type: $((temp / 1000))°C"
    done

    if [ -n "$AVAILABLE_MEM" ] && [ "$AVAILABLE_MEM" -lt "$THRESHOLD_MB" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Available RAM (${AVAILABLE_MEM}MB) < ${THRESHOLD_MB}MB. Clearing cache..."
        sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    fi

    sleep "$INTERVAL"
done
