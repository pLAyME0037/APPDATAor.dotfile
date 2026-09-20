import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

PanelWindow {
    id:             bar
    anchors {
        top:        true;
        left:       true;
        right:      true;
    }
    margins {
        top:        1;
        left:       1;
        right:      1;
    }
    implicitHeight: 25
    color:          "transparent"
    Poller {
        id:         clock
        command:    "date +%I:%M:%S"
        interval:   1000
    }
    Poller {
        id:         volumn
        command:    "wpctl get-volume @DEFAULT_AUDIO_SINK@"
        interval:   200
    }
    readonly property bool isMuted: volumn.value.indexOf("[MUTED]") !== -1
    readonly property string volumePercent: {
        var m = volumn.value.match(/([0-9.]+)/);
        return m ? Math.round(parseFloat(m[1])*100).toString() : "0";
    }

    Poller {
        id:       batteryInfo
        command:  "echo \"$(cat /sys/class/power_supply/BAT*/status 2>/dev/null),$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null)\""
        interval: 10000
    }
    readonly property var    batteryParts:  batteryInfo.value.trim().split(",")
    readonly property string batteryStatus: batteryParts[0] || ""
    readonly property int    batteryLevel:  parseInt(batteryParts[1]) || 0
    readonly property bool   isCharging:    batteryStatus === "Charging"

    readonly property string batteryIcon: {
        if (batteryStatus === "Full") return "󰂅";
        if (isCharging)               return "󰂄";
        if (batteryLevel <= 10)       return "󰂃";
        if (batteryLevel <= 20)       return "󰁻";
        if (batteryLevel <= 30)       return "󰁼";
        if (batteryLevel <= 50)       return "󰁾";
        if (batteryLevel <= 80)       return "󰂀";
        return "󰁹";
    }

    readonly property string batteryColor: {
        if (isCharging || batteryStatus === "Full") return "#a6e3a1"; // Green
        if (batteryLevel <= 10) return "#f38ba8";                    // Red
        if (batteryLevel <= 20) return "#fab387";                    // Orange
        return "#f2cdcd";                                           // Normal
    }
    Poller {
        id:         bluetooth
        command:    "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"
        interval:   5000
    }
    Poller {
        id:         network
        command:    "nmcli -t -f NAME connection show --active | head -n1"
        interval:   5000
    }
    Poller {
        id:         player
        command:    "playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null | sed 's/^ *- */ /; s/^ *//' || echo ''"
        interval:   1000
    }
    Poller {
        id:         windowTitle
        command:    "hyprctl activewindow -j | jq -r '.title'"
        interval:   250
    }
    readonly property var player: Mpris.players
                                       .values
                                       .find(p => p.isPlaying) ?? Mpris.players.values[0]
                                                               ?? null
    PlayerPopup {
        id: playerPopup
    }
    RowLayout {
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin:     6
        spacing:                0

        Pill {
            icon:               ""
            label:              ""
            iconColor:          "#f2cdcd"
            MouseArea {
                anchors.fill:   parent
                cursorShape:    Qt.PointingHandCursor
                onClicked: (mouse) => {
                    Quickshell.execDetached([
                        "rofi", "-show", "drun", "-drun-reload"
                    ]);
                }
            }
            // onCommand: (leader, esc) => {}
            Text {
                anchors.centerIn: parent
                text:             "\u{f08c7}" 
                color:            "#f2cdcd"
                font.pixelSize:   18
                font.weight:      Font.DemiBold
            }
        }
        Workspace {}
        Pill {
            icon:               "󰆾"
            label:              windowTitle.value
            iconColor:          "#f2cdcd"
            maxLabelWidth:      500
        }
    }

    property bool showDateMode: false
    CalendarPopup {
        id: calendarPopup
    }
    RowLayout {
        anchors.centerIn:       parent
        spacing:                8

        Pill {
            icon:      bar.showDateMode ? "󰸗" : "󰥔"
            label:     bar.showDateMode ? Qt.formatDate(new Date(), "dd-MMM-yyyy")
                                        : clock.value
            iconColor: "#f2cdcd"

            MouseArea {
                anchors.fill:    parent
                cursorShape:     Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        bar.showDateMode = !bar.showDateMode;
                    } else if (mouse.button === Qt.LeftButton) {
                        calendarPopup.open = !calendarPopup.open;
                    }
                }
            }
        }
    }
    Poller {
        id: hwPoller
        command: "
        cpu=$(top -bn1 | awk '/Cpu/ {printf \"%.0f\", 100 - $8}');
        gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0);
        mem=($(free -m | awk '/Mem:/ {printf \"%d %d %.0f\", $3, $2, ($3/$2)*100}'));
        disk=($(df -h / | awk 'NR==2 {printf \"%s %s %s\", $3, $2, $5}'));
        procs=$(ps -eo comm,%cpu --sort=-%cpu | head -n 6 | tail -n +2 | awk '{printf \"%s:%s,\", $1, $2}');
        echo \"$cpu|$gpu|${mem[0]}|${mem[1]}|${mem[2]}|${disk[0]}|${disk[1]}|${disk[2]}|$procs\""
        interval: 2000
    }
    readonly property var    hwData:   hwPoller.value.trim().split("|")
    readonly property string cpuUsage: hwData[0] || "0"
    readonly property string gpuUsage: hwData[1] || "0"
    readonly property string memUsage: hwData[2] || "0"
    HardwarePopup { id: hwPopup }

    RowLayout {
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin:    6
        spacing:                8
        Pill {
            icon:               "󰍛"
            label:              "CPU " + bar.cpuUsage + "%"
            iconColor:          "#f2cdcd"

            MouseArea {
                anchors.fill:   parent
                cursorShape:    Qt.PointingHandCursor
                onClicked:      hwPopup.open = !hwPopup.open
            }
        }
        Pill {
            icon:               "󰎈"
            label:              player.value
            iconColor:          "#f2cdcd"
            maxLabelWidth:      150

            MouseArea {
                anchors.fill:   parent
                cursorShape:    Qt.PointingHandCursor
                onClicked: {
                    playerPopup.open = !playerPopup.open;
                }
            }
        }
        Pill {
            icon:                bar.isMuted ? "\u{f075f}" : "\u{eb75}"
            label:               bar.isMuted ? "" : (bar.volumePercent + "%")
            iconColor:           "#f2cdcd"

            MouseArea {
                anchors.fill:    parent
                cursorShape:     Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                    } else if (mouse.button === Qt.LeftButton) {
                        Quickshell.execDetached(["pavucontrol"]);
                    }
                }

                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "3%+"]);
                    } else if (wheel.angleDelta.y < 0) {
                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "3%-"]);
                    }
                }
            }
        }
        Pill {
            icon:               "󰂰"
            label:              bluetooth.value
            iconColor:          "#f2cdcd"
        }
        Pill {
            icon:               "󰖩"
            label:              network.value
            iconColor:          "#f2cdcd"
        }
        Pill {
            icon:               bar.batteryIcon
            label:              bar.batteryLevel + "%"
            iconColor:          bar.batteryColor
        }
    }
}
