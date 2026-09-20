import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Rectangle {
    implicitWidth:                    row.implicitWidth + 22
    implicitHeight:                   25
    radius:                           height/2
    color:                            "#121218"
    property int activeWs:            Hyprland.focusedWorkspace?.id ?? 1
    RowLayout {
        id:                           row
        anchors.centerIn:             parent
        spacing:                      8
        Repeater {
            model:                    5
            Rectangle {
                property int wsIndex: index + 1
                implicitWidth:        wsIndex === activeWs ? 25 : 18
                implicitHeight:       25
                radius:               3
                color:                wsIndex === activeWs ? "#45475a" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text:             wsIndex
                    color:            wsIndex === activeWs ? "#cdd6f4" : "#6c7086"
                    font.pixelSize:   12
                    font.weight:      Font.DemiBold
                }
                Rectangle {
                    anchors.bottom:   parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:            parent.width
                    height:           3
                    radius:           1
                    color:            "#bac2de"
                    visible:          wsIndex === activeWs
                }
                Behavior on implicitWidth {
                    NumberAnimation {
                        duration:     160
                        easing.type:  Easing.OutCubic
                    }
                }
                MouseArea {
                    anchors.fill:     parent
                    onClicked:        Hyprland.dispatch("workspace", wsIndex)
                }
            }
        }
    }
}
