#!/usr/bin/env bash

uptime="$(uptime -p | sed -e 's/up //g')"

shutdown='󰐥'
reboot='󰜉'
suspend=''
logout='󰍃'
cancel='󰅖'

chosen=$(printf '%s\n' "$shutdown" "$reboot" "$suspend" "$logout" "$cancel" | rofi -dmenu -p "" -mesg "Uptime: $uptime" -theme "$HOME/.config/rofi/themes/powermenu.rasi")

case "$chosen" in
"$shutdown")
    systemctl poweroff
;;
"$reboot")
    systemctl reboot
;;
"$suspend")
    systemctl suspend
;;
"$logout")
    hyprctl dispatch exit
;;
"$cancel")
    exit 0
;;
esac
