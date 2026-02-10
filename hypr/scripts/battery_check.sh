#!/bin/bash

# Configuration
LOW_BATTERY=20
CRITICAL_BATTERY=10
CHECK_INTERVAL=120 # seconds

# Automatically find the battery path
BAT_PATH=$(find /sys/class/power_supply/ -name "BAT*" | head -n 1)

# Ensure notify-send can find the desktop session
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

while true; do
    if [ -f "$BAT_PATH/capacity" ]; then
        BATTERY_LEVEL=$(cat "$BAT_PATH/capacity")
        BATTERY_STATUS=$(cat "$BAT_PATH/status")

        if [ "$BATTERY_STATUS" = "Discharging" ]; then
            if [ "$BATTERY_LEVEL" -le "$CRITICAL_BATTERY" ]; then
                notify-send -u critical "BATTERY CRITICAL" "Plug in charger immediately! ($BATTERY_LEVEL%)"
            elif [ "$BATTERY_LEVEL" -le "$LOW_BATTERY" ]; then
                notify-send -u normal "Battery Low" "Level is at $BATTERY_LEVEL%"
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
