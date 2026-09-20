import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id:                 root
    visible:            open
    implicitWidth:      320
    implicitHeight:     340
    color:              "transparent"

    property bool open: false

    anchor.window:      bar
    anchor.rect.x:      bar.width - 340
    anchor.rect.y:      bar.height + 6

    HyprlandFocusGrab {
        active:         root.open
        windows:        [root]
        onCleared:      root.open = false
    }

    readonly property int    cpuPct:    parseInt(bar.hwData[0]) || 0
    readonly property int    gpuPct:    parseInt(bar.hwData[1]) || 0
    readonly property string memUsed:   bar.hwData[2] || "0"
    readonly property string memTotal:  bar.hwData[3] || "0"
    readonly property int    memPct:    parseInt(bar.hwData[4]) || 0
    readonly property string diskUsed:  bar.hwData[5] || "0"
    readonly property string diskTotal: bar.hwData[6] || "0"
    readonly property string diskPct:   bar.hwData[7] || "0%"
    readonly property var    procs:     (bar.hwData[8] || "").split(",").filter(x => x.length > 0)

    Rectangle {
        anchors.fill: parent
        radius:       12
        color:        "#1e1e2e"
        border.width: 1
        border.color: "#313244"

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 14
            spacing:         10

            // Title + Launch btop
            RowLayout {
                Layout.fillWidth:     true
                Text {
                    text:             "System Status"
                    color:            "#cdd6f4"
                    font.bold:        true
                    font.pixelSize:   14
                }
                Item {
                    Layout.fillWidth: true
                }
                Button {
                    text:             "Open btop"
                    onClicked: {
                        Quickshell.execDetached(["kitty", "-e", "btop"]) // swap kitty if use other term
                        root.open =   false
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth:       true
                spacing:                2
                RowLayout {
                    Text {
                        text:           "CPU"
                        color:          "#a6adc8"
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text:           root.cpuPct + "%"
                        color:          "#cdd6f4"
                        font.pixelSize: 11
                    }
                }
                Rectangle {
                    Layout.fillWidth:   true
                    height:             6
                    radius:             3
                    color:              "#313244"
                    Rectangle {
                        width: parent.width * (Math.min(root.cpuPct, 100) / 100)
                        height: parent.height
                        radius: 3
                        color: root.cpuPct > 80 ? "#f38ba8" : "#89b4fa"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth:       true
                spacing:                2
                RowLayout {
                    Text {
                        text:           "GPU"
                        color:          "#a6adc8"
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text:           root.gpuPct + "%"
                        color:          "#cdd6f4"
                        font.pixelSize: 11
                    }
                }
                Rectangle {
                    Layout.fillWidth:   true
                    height:             6
                    radius:             3
                    color:              "#313244"
                    Rectangle {
                        width: parent.width * (Math.min(root.gpuPct, 100) / 100)
                        height: parent.height
                        radius: 3
                        color: root.gpuPct > 80 ? "#f38ba8" : "#89b4fa"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing:          2
                RowLayout {
                    Text {
                        text: "Memory (" + root.memUsed + "M / " + root.memTotal + "M)"
                        color: "#a6adc8"
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.memPct + "%"
                        color: "#cdd6f4"
                        font.pixelSize: 11
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height:           6
                    radius:           3
                    color:            "#313244"
                    Rectangle {
                        width: parent.width * (Math.min(root.memPct, 100) / 100)
                        height: parent.height
                        radius: 3
                        color: root.memPct > 85 ? "#f38ba8" : "#a6e3a1"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Text { 
                        text: "Disk (" + root.diskUsed + " / " + root.diskTotal + ")"
                        color: "#a6adc8"
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text:           root.diskPct
                        color:          "#cdd6f4"
                        font.pixelSize: 11 
                    }
                }
            }

            Rectangle { 
                Layout.fillWidth: true
                height:           1
                color:            "#313244"
            }

            Text { 
                text:           "Top Processes (CPU)"
                color:          "#f2cdcd"
                font.bold:      true
                font.pixelSize: 11
            }

            ListView {
                Layout.fillWidth:         true
                Layout.fillHeight:        true
                model:                    root.procs
                delegate: RowLayout {
                    width:                parent.width
                    property var p:       modelData.split(":")
                    Text { 
                        text:             p[0] || ""
                        color:            "#cdd6f4"
                        font.pixelSize:   11
                        Layout.fillWidth: true
                        elide:            Text.ElideRight
                    }
                    Text {
                        text:             (p[1] || "0") + "%"
                        color:            "#fab387"
                        font.pixelSize:   11
                    }
                }
            }
        }
    }
}
