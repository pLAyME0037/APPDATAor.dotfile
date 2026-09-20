import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

PopupWindow {
    id:             root
    visible:        open
    implicitWidth:  340
    implicitHeight: 150
    color:          "transparent"
    grabFocus:      false

    property bool open: false

    anchor.window: bar
    anchor.rect.x: bar.width - 350
    anchor.rect.y: bar.height + 4

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.open = false
    }

    // Fully reactive player selection and metadata bindings
    readonly property var currentPlayer: {
        var players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }

    readonly property bool   isPlaying: currentPlayer?.isPlaying ?? false
    readonly property string title:     currentPlayer?.trackTitle ?? ""
    readonly property string artist:    currentPlayer?.trackArtist ?? ""
    readonly property string identity:  currentPlayer?.identity ?? ""
    readonly property string artUrl:    currentPlayer?.trackArtUrl ?? ""

    // Preferred font family for Nerd Font / MDI glyphs
    readonly property string iconFont: "Symbols Nerd Font, Material Design Icons, JetBrainsMono Nerd Font, monospace"

    Rectangle {
        anchors.fill:    parent
        anchors.margins: 1
        radius:          12
        color:           "#1e1e2e"
        border.width:    1
        border.color:    "#313244"

        RowLayout {
            spacing:         12
            anchors.fill:    parent
            anchors.margins: 12

            // Album art
            Rectangle {
                implicitWidth:  110
                implicitHeight: 110
                radius:         8
                color:          "#313244"
                clip:           true

                Image {
                    id:             artImg
                    anchors.fill:   parent
                    source:         root.artUrl
                    fillMode:       Image.PreserveAspectCrop
                    asynchronous:   true
                    visible:        status === Image.Ready && source != ""
                }

                // Placeholder icon if album art fails/loads
                Text {
                    anchors.centerIn: parent
                    text:             "\u{F075A}" // mdi-music
                    font.family:      root.iconFont
                    color:            "#6c7086"
                    font.pixelSize:   36
                    visible:          !artImg.visible
                }
            }

            // Info + controls
            ColumnLayout {
                Layout.fillWidth: true
                spacing:          4

                Text {
                    text:                root.title !== "" ? root.title : "No media playing"
                    color:               "#cdd6f4"
                    font.pixelSize:      13
                    font.bold:           true
                    elide:               Text.ElideRight
                    Layout.fillWidth:    true
                    Layout.maximumWidth: 190
                }

                Text {
                    text:                root.artist
                    color:               "#a6adc8"
                    font.pixelSize:      11
                    elide:               Text.ElideRight
                    Layout.fillWidth:    true
                    Layout.maximumWidth: 190
                    visible:             root.artist !== ""
                }

                Text {
                    text:                root.identity
                    color:               "#585b70"
                    font.pixelSize:      10
                    elide:               Text.ElideRight
                    Layout.fillWidth:    true
                    Layout.maximumWidth: 190
                    visible:             root.identity !== ""
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing:          16

                    // Previous Button
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: prevArea.containsMouse ? "#45475a" : "transparent"
                        opacity: root.currentPlayer ? 1.0 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text:             "\u{F04AE}" // mdi-skip-previous
                            font.family:      root.iconFont
                            color:            "#cdd6f4"
                            font.pixelSize:   16
                        }

                        MouseArea {
                            id:           prevArea
                            anchors.fill: parent
                            hoverEnabled: root.currentPlayer !== null
                            enabled:      root.currentPlayer !== null
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.currentPlayer?.previous()
                        }
                    }

                    // Play/Pause Button
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: playArea.containsMouse ? "#45475a" : "#313244"
                        opacity: root.currentPlayer ? 1.0 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text:             root.isPlaying ? "\u{f04c}" : "\u{F040A}" // mdi-pause / mdi-play
                            font.family:      root.iconFont
                            color:            "#cdd6f4"
                            font.pixelSize:   18
                        }

                        MouseArea {
                            id:           playArea
                            anchors.fill: parent
                            hoverEnabled: root.currentPlayer !== null
                            enabled:      root.currentPlayer !== null
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.currentPlayer?.togglePlaying()
                        }
                    }

                    // Next Button
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: nextArea.containsMouse ? "#45475a" : "transparent"
                        opacity: root.currentPlayer ? 1.0 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text:             "\u{F04AD}" // mdi-skip-next
                            font.family:      root.iconFont
                            color:            "#cdd6f4"
                            font.pixelSize:   16
                        }

                        MouseArea {
                            id:           nextArea
                            anchors.fill: parent
                            hoverEnabled: root.currentPlayer !== null
                            enabled:      root.currentPlayer !== null
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.currentPlayer?.next()
                        }
                    }
                }
            }
        }
    }
}
