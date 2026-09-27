import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

PopupWindow {
    id: root
    visible: open
    implicitWidth: 420
    implicitHeight: 680
    color: "transparent"

    property bool open: false

    anchor.window: bar
    anchor.rect.x: bar.width - 440
    anchor.rect.y: bar.height + 8

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.open = false
    }

    // Tray menu popup anchor (menu handle has no .popup())
    QsMenuAnchor {
        id: trayMenuAnchor
        anchor.window: root
        anchor.rect.x: 24
        anchor.rect.y: implicitHeight - 48
    }

    // ---- Retro toggle component ----
    component RetroToggle: Rectangle {
        id: toggle
        property bool checked: false
        signal toggled()
        Layout.preferredWidth: 40
        Layout.preferredHeight: 18
        radius: 0
        color: checked ? "#0a2a1a" : root.bgDeep
        border.width: 1
        border.color: checked ? root.accentGreen : root.borderBright

        Rectangle {
            width: 14; height: 14
            x: toggle.checked ? 24 : 2
            y: 2
            color: toggle.checked ? root.accentGreen : root.fgDim
            Behavior on x { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    // ---- Pollers ----
    Poller {
        id: wifiStatus;
        command: "nmcli -t -f WIFI g";
        interval: 3000
    }
    Poller {
        id: wifiList;
        command: "nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list | head -n20";
        interval: 5000
    }
    Poller {
        id: linkInfo;
        command: "nmcli -t -f ACTIVE,RATE,FREQ,CHAN dev wifi list | grep '^yes' | head -n1 | cut -d: -f2-";
        interval: 5000
    }
    Poller {
        id: btAdapter;
        command: "bluetoothctl show | awk '/Name:/{n=$2} /Powered:/{p=$2} /Discovering:/{d=$2} END{print n\"|\"p\"|\"d}'";
        interval: 3000
    }
    Poller {
        id: bluetoothDevices;
        command: "bluetoothctl devices | sed 's/^Device //' | while read mac name; do i=$(bluetoothctl info \"$mac\" 2>/dev/null); pr=$(echo \"$i\" | awk '/Paired:/{print $2}'); c=$(echo \"$i\" | awk '/Connected:/{print $2}'); echo \"$mac|$name|$pr|$c\"; done";
        interval: 4000
    }
    // Rate over 1s: outputs "RX_MBps TX_MBps"
    Poller {
        id: networkStats
        interval: 3000
        command: "f(){ awk '/wlan|wlp|wlx/{r+=$2;t+=$10} END{print r, t}' /proc/net/dev; }; a=$(f); sleep 1; b=$(f); set -- $a; r1=$1; t1=$2; set -- $b; awk -v r1=$r1 -v t1=$t1 -v r2=$1 -v t2=$2 'BEGIN{printf \"%.3f %.3f\", (r2-r1)/1048576, (t2-t1)/1048576}'"
    }
    Poller {
        id: hotspotStatus;
        command: "nmcli -t -f NAME,TYPE connection show --active | grep ':802-11-wireless$' | grep -qi hotspot && echo on || echo off";
        interval: 3000
    }
    Poller {
        id: hotspotInfo;
        command: "c=$(nmcli -t -f NAME connection show | grep -i hotspot | head -n1); if [ -n \"$c\" ]; then s=$(nmcli -g 802-11-wireless.ssid connection show \"$c\"); k=$(nmcli -g 802-11-wireless-security.key-mgmt connection show \"$c\" 2>/dev/null); echo \"$s:$k\"; fi";
        interval: 5000
    }

    readonly property bool   wifiEnabled:    wifiStatus.value.trim() === "enabled"
    readonly property var    btAdapterData:  (btAdapter.value || "|||").split("|")
    readonly property string btAdapterName:  btAdapterData[0] || "-"
    readonly property bool   btEnabled:      btAdapterData[1] === "yes"
    readonly property bool   btDiscovering:  btAdapterData[2] === "yes"
    readonly property bool   hotspotEnabled: hotspotStatus.value.trim() === "on"
    readonly property var    netStats:       (networkStats.value || "0 0").trim().split(/\s+/)
    readonly property real   rxRate:         parseFloat(root.netStats[0]) || 0   // MB/s
    readonly property real   txRate:         parseFloat(root.netStats[1]) || 0   // MB/s
    readonly property var    linkParts:      (linkInfo.value || "").split(":")
    readonly property string linkRate:       root.linkParts[0] || "-"
    readonly property string linkFreq:       root.linkParts[1] || "-"
    readonly property string linkChan:       root.linkParts[2] || "-"
    readonly property string hotspotSSID: {
        var p = (hotspotInfo.value || "").split(":");
        return p[0] || "HOTSPOT";
    }
    readonly property string hotspotSecurity: {
        var p = (hotspotInfo.value || "").split(":");
        return p[1] || "WPA2";
    }

    // Password prompt state
    property string pendingSsid: ""
    property string pendingSecurity: ""

    property color bgDeep:       "#0a0a0f"
    property color bgCard:       "#11111a"
    property color borderDim:    "#2a2a3e"
    property color borderBright: "#3a3a5a"
    property color fgPrimary:    "#e8e8f0"
    property color fgMuted:      "#6a6a8a"
    property color fgDim:        "#4a4a6a"
    property color accentGreen:  "#00ff88"
    property color accentAmber:  "#ffb800"
    property color accentCyan:   "#00e5ff"
    property color accentRed:    "#ff4466"
    property color accentPurple: "#b888ff"

    function formatRate(mbps) {
        if (mbps < 0.001) return "0 KB/s";
        if (mbps < 1) return (mbps * 1024).toFixed(0) + " KB/s";
        if (mbps >= 1024) return (mbps / 1024).toFixed(2) + " GB/s";
        return mbps.toFixed(1) + " MB/s";
    }

    function parseWifiList(output) {
        var lines = (output || "").trim().split("\n"), result = [];
        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split(":");
            if (p.length >= 3 && p[0].length) {
                result.push({
                    ssid: p[0],
                    signal: parseInt(p[1]) || 0,
                    security: p[2] || "none",
                    inUse: p.length > 3 && p[3] === "*"
                });
            }
        }
        result.sort((a, b) => a.inUse !== b.inUse ? (a.inUse ? -1 : 1) : b.signal - a.signal);
        return result;
    }

    function parseBtDevices(output) {
        var lines = (output || "").trim().split("\n"), result = [];
        for (var i = 0; i < lines.length; i++) if (lines[i].length) {
            var p = lines[i].split("|");
            if (p.length >= 4 && p[0].length) {
                result.push({ mac: p[0], name: p[1] || "UNKNOWN", paired: p[2] === "yes", connected: p[3] === "yes" });
            }
        }
        result.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
        return result;
    }

    function btDeviceAction(mac, paired, connected) {
        if (!btEnabled) return;
        if (connected) Quickshell.execDetached(["bluetoothctl", "disconnect", mac]);
        else if (paired) Quickshell.execDetached(["bluetoothctl", "connect", mac]);
        else Quickshell.execDetached(["sh", "-c", "bluetoothctl pair " + mac + " && bluetoothctl connect " + mac]);
        bluetoothDevices.trigger();
    }

    function btScanToggle() {
        if (!btEnabled) return;
        if (btDiscovering) Quickshell.execDetached(["bluetoothctl", "scan", "off"]);
        else Quickshell.execDetached(["bluetoothctl", "--timeout", "15", "scan", "on"]);
        btAdapter.trigger();
    }

    function connectToWifi(ssid, security) {
        if (security !== "none" && security !== "--") {
            pendingSsid = ssid;
            pendingSecurity = security;
            pwField.text = "";
            pwField.forceActiveFocus();
        } else {
            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid]);
            wifiList.trigger(); wifiStatus.trigger();
        }
    }

    function confirmConnect() {
        if (!pendingSsid.length) return;
        if (pwField.text.length > 0) {
            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", pendingSsid, "password", pwField.text]);
        }
        pendingSsid = ""; pendingSecurity = ""; pwField.text = "";
        wifiList.trigger(); wifiStatus.trigger();
    }

    // ---- Delegates ----
    Component { id: wifiNetworkDelegate
        Rectangle {
            id: wifiItem
            height: 42
            width: ListView.view ? ListView.view.width : 300
            radius: 0
            color: inUse ? "#0a1a0a" : (mouseArea.containsMouse ? "#181824" : "transparent")
            border.width: 1
            border.color: inUse ? root.accentGreen : "transparent"

            property string ssid: modelData.ssid
            property int sig: modelData.signal
            property string security: modelData.security
            property bool inUse: modelData.inUse

            // Full-row click target (background layer)
            MouseArea {
                id: mouseArea;
                anchors.fill: parent;
                cursorShape: Qt.PointingHandCursor;
                onClicked: root.connectToWifi(wifiItem.ssid, wifiItem.security)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 10
                z: 1

                // Signal bars (vertical, retro)
                Row {
                    spacing: 2
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 4
                            height: 4 + index * 3
                            color: index < (wifiItem.sig >= 75 ? 4 : wifiItem.sig >= 50 ? 3 : wifiItem.sig >= 25 ? 2 : 1) ? root.accentGreen : root.borderDim
                        }
                    }
                }

                Text {
                    text: wifiItem.ssid.toUpperCase() + (wifiItem.inUse ? "  ◉" : "")
                    color: wifiItem.inUse ? root.accentGreen : root.fgPrimary
                    font.family: "monospace"
                    font.pixelSize: 12
                    font.bold: wifiItem.inUse
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: wifiItem.sig + "%"
                    color: root.fgMuted
                    font.family: "monospace"
                    font.pixelSize: 10
                }
                Text {
                    text: (wifiItem.security === "none" || wifiItem.security === "--") ? "[OPEN]" : "[SEC]"
                    color: (wifiItem.security === "none" || wifiItem.security === "--") ? root.accentRed : root.accentAmber
                    font.family: "monospace"
                    font.pixelSize: 10
                }
            }
        }
    }

    Component { id: btDeviceDelegate
        Rectangle {
            height: 44
            width: ListView.view ? ListView.view.width : 300
            radius: 0
            color: btMouse.containsMouse ? "#181824" : "transparent"

            // Full-row click target (background layer)
            MouseArea {
                id: btMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.btDeviceAction(modelData.mac, modelData.paired, modelData.connected)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 10
                z: 1

                // Status dot
                Rectangle {
                    Layout.preferredWidth: 7; Layout.preferredHeight: 7
                    color: modelData.connected ? root.accentGreen : modelData.paired ? root.accentCyan : root.fgDim
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: modelData.name.toUpperCase()
                            color: modelData.connected ? root.accentGreen : modelData.paired ? root.fgPrimary : root.fgMuted
                            font.family: "monospace"
                            font.pixelSize: 11
                            font.bold: modelData.connected
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.connected ? "[CONN]" : modelData.paired ? "[PAIRED]" : "[NEW]"
                            color: modelData.connected ? root.accentGreen : modelData.paired ? root.accentCyan : root.fgDim
                            font.family: "monospace"
                            font.pixelSize: 9
                        }
                    }
                    Text {
                        text: modelData.mac
                        color: root.fgDim
                        font.family: "monospace"
                        font.pixelSize: 9
                    }
                }

                // Action hint
                Text {
                    text: modelData.connected ? "DISCONNECT" : modelData.paired ? "CONNECT" : "PAIR"
                    color: btMouse.containsMouse
                        ? (modelData.connected ? root.accentRed : modelData.paired ? root.accentGreen : root.accentAmber)
                        : root.fgDim
                    font.family: "monospace"
                    font.pixelSize: 9
                }
            }
        }
    }

    // ---- Main container ----
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.bgDeep
        border.width: 1
        border.color: root.borderBright

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.borderDim }
                Text {
                    text: " NETWORK CTRL "
                    color: root.accentGreen
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.borderDim }
            }

            // ===== WiFi Section =====
            Rectangle {
                id: wifiCard
                Layout.fillWidth: true
                Layout.minimumHeight: 150
                Layout.preferredHeight: wifiCol.implicitHeight + 24
                Layout.fillHeight: true
                radius: 0
                color: root.bgCard
                border.width: 1
                border.color: root.borderDim

                ColumnLayout {
                    id: wifiCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "WIFI"; color: root.wifiEnabled ? root.accentGreen : root.accentRed; font.family: "monospace"; font.pixelSize: 12; font.bold: true }
                        Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; color: root.wifiEnabled ? root.accentGreen : root.accentRed }
                        Item { Layout.fillWidth: true }
                        RetroToggle { checked: root.wifiEnabled; onToggled: { Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]); wifiStatus.trigger(); } }
                    }

                    // Link info: bandwidth + freq + channel
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.wifiEnabled
                        spacing: 16
                        Text {
                            text: "LINK " + root.linkRate + " @ " + root.linkFreq + " ch" + root.linkChan
                            color: root.fgMuted
                            font.family: "monospace"
                            font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // Bandwidth rates with visual bars
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 8
                        rowSpacing: 6

                        Text { text: "RX"; color: root.fgMuted; font.family: "monospace"; font.pixelSize: 10; Layout.preferredWidth: 18 }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 5; color: root.bgDeep; border.width: 1; border.color: root.borderDim
                            Rectangle { width: parent.width * Math.min(root.rxRate / 10, 1); height: parent.height; color: root.accentCyan
                                Behavior on width { NumberAnimation { duration: 250 } } }
                        }
                        Text { text: root.formatRate(root.rxRate); color: root.accentCyan; font.family: "monospace"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignRight }

                        Text { text: "TX"; color: root.fgMuted; font.family: "monospace"; font.pixelSize: 10; Layout.preferredWidth: 18 }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 5; color: root.bgDeep; border.width: 1; border.color: root.borderDim
                            Rectangle { width: parent.width * Math.min(root.txRate / 10, 1); height: parent.height; color: root.accentPurple
                                Behavior on width { NumberAnimation { duration: 250 } } }
                        }
                        Text { text: root.formatRate(root.txRate); color: root.accentPurple; font.family: "monospace"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignRight }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.borderDim }

                    // Password prompt (inline, replaces prompt())
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.pendingSsid !== ""
                        spacing: 6
                        Text {
                            text: "PWD ▸ " + root.pendingSsid.toUpperCase()
                            color: root.accentAmber
                            font.family: "monospace"
                            font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.pendingSsid !== ""
                        spacing: 6
                        TextField {
                            id: pwField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            placeholderText: "password..."
                            echoMode: TextInput.Password
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: root.fgPrimary
                            placeholderTextColor: root.fgDim
                            selectionColor: root.accentGreen
                            onAccepted: root.confirmConnect()
                            background: Rectangle {
                                color: root.bgDeep
                                border.width: 1
                                border.color: pwField.activeFocus ? root.accentGreen : root.borderBright
                            }
                        }
                        Button {
                            text: "OK"
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 28
                            background: Rectangle { color: "#0a1a0a"; border.width: 1; border.color: root.accentGreen }
                            contentItem: Text { text: "OK"; color: root.accentGreen; font.family: "monospace"; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: root.confirmConnect()
                        }
                        Button {
                            text: "X"
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            background: Rectangle { color: root.bgDeep; border.width: 1; border.color: root.borderBright }
                            contentItem: Text { text: "X"; color: root.fgMuted; font.family: "monospace"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: { root.pendingSsid = ""; root.pendingSecurity = ""; pwField.text = ""; }
                        }
                    }

                    // Network list
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 120
                        clip: true
                        spacing: 1
                        model: root.parseWifiList(wifiList.value)
                        delegate: wifiNetworkDelegate
                    }
                }
            }

            // ===== Hotspot Section =====
            Rectangle {
                Layout.fillWidth: true
                radius: 0
                color: root.bgCard
                border.width: 1
                border.color: root.hotspotEnabled ? root.accentAmber : root.borderDim
                implicitHeight: hsCol.implicitHeight + 24

                ColumnLayout {
                    id: hsCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "HOTSPOT"; color: root.hotspotEnabled ? root.accentAmber : root.fgMuted; font.family: "monospace"; font.pixelSize: 12; font.bold: true }
                        Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; color: root.hotspotEnabled ? root.accentAmber : root.borderDim }
                        Item { Layout.fillWidth: true }
                        RetroToggle {
                            checked: root.hotspotEnabled
                            onToggled: {
                                if (root.hotspotEnabled) Quickshell.execDetached(["nmcli", "con", "down", "Hotspot"]);
                                else Quickshell.execDetached(["nmcli", "con", "up", "Hotspot"]);
                                hotspotStatus.trigger();
                            }
                        }
                    }

                    // Details when enabled
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.hotspotEnabled
                        spacing: 6

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 12
                            rowSpacing: 4
                            Text { text: "SSID"; color: root.fgMuted; font.family: "monospace"; font.pixelSize: 10 }
                            Text { text: root.hotspotSSID.toUpperCase(); color: root.accentAmber; font.family: "monospace"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: "SEC"; color: root.fgMuted; font.family: "monospace"; font.pixelSize: 10 }
                            Text { text: root.hotspotSecurity.toUpperCase(); color: root.fgPrimary; font.family: "monospace"; font.pixelSize: 11; Layout.fillWidth: true }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Item { Layout.fillWidth: true }
                            Button {
                                Layout.preferredWidth: 92; Layout.preferredHeight: 26
                                background: Rectangle { color: "#1a1a0a"; border.width: 1; border.color: root.accentAmber }
                                contentItem: Text { text: "QR CODE"; color: root.accentAmber; font.family: "monospace"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: Quickshell.execDetached(["nmcli", "dev", "wifi", "show-password"])
                            }
                            Button {
                                Layout.preferredWidth: 60; Layout.preferredHeight: 26
                                background: Rectangle { color: root.bgDeep; border.width: 1; border.color: root.borderBright }
                                contentItem: Text { text: "EDIT"; color: root.fgPrimary; font.family: "monospace"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: Quickshell.execDetached(["nm-connection-editor"])
                            }
                        }
                    }

                    // When disabled
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.hotspotEnabled
                        spacing: 8
                        Text { text: "[ NOT CONFIGURED ]"; color: root.fgDim; font.family: "monospace"; font.pixelSize: 10 }
                        Item { Layout.fillWidth: true }
                        Button {
                            Layout.preferredWidth: 120; Layout.preferredHeight: 26
                            background: Rectangle { color: "#1a1a0a"; border.width: 1; border.color: root.accentAmber }
                            contentItem: Text { text: "CREATE HOTSPOT"; color: root.accentAmber; font.family: "monospace"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: Quickshell.execDetached(["nm-connection-editor"])
                        }
                    }
                }
            }

            // ===== Bluetooth Section =====
            Rectangle {
                Layout.fillWidth: true
                radius: 0
                color: root.bgCard
                border.width: 1
                border.color: root.btEnabled ? root.accentCyan : root.borderDim
                implicitHeight: btCol.implicitHeight + 24

                ColumnLayout {
                    id: btCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Header: name + status + scan + toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "BLUETOOTH"; color: root.btEnabled ? root.accentCyan : root.accentRed; font.family: "monospace"; font.pixelSize: 12; font.bold: true }
                        Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; color: root.btEnabled ? root.accentCyan : root.accentRed }
                        Text {
                            text: root.btAdapterName.toUpperCase()
                            color: root.fgMuted
                            font.family: "monospace"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.maximumWidth: 90
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            Layout.preferredWidth: root.btDiscovering ? 84 : 60
                            Layout.preferredHeight: 24
                            enabled: root.btEnabled
                            opacity: root.btEnabled ? 1.0 : 0.4
                            background: Rectangle {
                                color: root.btDiscovering ? "#1a0a1a" : root.bgDeep
                                border.width: 1
                                border.color: root.btDiscovering ? root.accentAmber : root.borderBright
                            }
                            contentItem: Text {
                                text: root.btDiscovering ? "■ STOP" : "⌕ SCAN"
                                color: root.btDiscovering ? root.accentAmber : root.fgPrimary
                                font.family: "monospace"
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.btScanToggle()
                        }
                        RetroToggle {
                            checked: root.btEnabled;
                            onToggled: {
                                Quickshell.execDetached(["bluetoothctl", "power", root.btEnabled ? "off" : "on"]);
                                btAdapter.trigger();
                            }
                        }
                    }

                    // Status line
                    Text {
                        Layout.fillWidth: true
                        visible: root.btEnabled
                        text: root.btDiscovering 
                            ? "STATUS: DISCOVERING DEVICES..." 
                            : "STATUS: " + root.parseBtDevices(bluetoothDevices.value).length + " DEVICE(S)"
                        color: root.btDiscovering ? root.accentAmber : root.fgDim
                        font.family: "monospace"
                        font.pixelSize: 9
                    }

                    // Empty hint
                    Text {
                        Layout.fillWidth: true
                        visible: root.btEnabled && bluetoothDevices.value.trim().length === 0
                        text: "[ NO DEVICES — HIT SCAN TO DISCOVER ]"
                        color: root.fgDim
                        font.family: "monospace"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        padding: 6
                    }

                    // Powered-off hint
                    Text {
                        Layout.fillWidth: true
                        visible: !root.btEnabled
                        text: "[ ADAPTER POWERED OFF ]"
                        color: root.fgDim
                        font.family: "monospace"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        padding: 6
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 140)
                        Layout.maximumHeight: 140
                        clip: true
                        spacing: 1
                        model: root.parseBtDevices(bluetoothDevices.value)
                        delegate: btDeviceDelegate
                    }
                }
            }

            // ===== System Tray =====
            Rectangle {
                Layout.fillWidth: true
                radius: 0
                color: root.bgCard
                border.width: 1
                border.color: root.borderDim
                implicitHeight: trayCol.implicitHeight + 24

                ColumnLayout {
                    id: trayCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "SYS TRAY";
                        color: root.accentPurple;
                        font.family: "monospace";
                        font.pixelSize: 12;
                        font.bold: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            visible: SystemTray.items.values.length === 0
                            text: "[ NO TRAY ITEMS ]"
                            color: root.fgDim
                            font.family: "monospace"
                            font.pixelSize: 10
                        }

                        Repeater {
                            model: SystemTray.items
                            delegate: Rectangle {
                                required property var modelData
                                width: 32; height: 32
                                radius: 0
                                color: trayMouse.containsMouse ? "#181824" : root.bgDeep
                                border.width: 1
                                border.color: trayMouse.containsMouse ? root.accentPurple : root.borderDim
                                Image {
                                    anchors.centerIn: parent
                                    source: modelData.icon
                                    width: 18; height: 18
                                    fillMode: Image.PreserveAspectFit
                                }
                                MouseArea {
                                    id: trayMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        var wantMenu = modelData.hasMenu && (mouse.button === Qt.RightButton || modelData.onlyMenu);
                                        if (wantMenu) {
                                            trayMenuAnchor.menu = modelData.menu;
                                            var p = mapToItem(null, mouse.x, mouse.y);
                                            trayMenuAnchor.anchor.rect.x = p.x;
                                            trayMenuAnchor.anchor.rect.y = p.y;
                                            trayMenuAnchor.open();
                                        } else if (modelData.activate) {
                                            modelData.activate();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
