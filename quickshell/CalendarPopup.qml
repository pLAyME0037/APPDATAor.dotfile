import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PopupWindow {
    id: root
    visible: open
    implicitWidth: 380
    implicitHeight: 520
    color: "transparent"

    property bool open: false
    property date viewDate: new Date()
    property string selectedDateStr: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property var notesData: ({})

    // Center horizontally, below bar
    anchor.window: bar
    anchor.rect.x: (bar.width - width) / 2
    anchor.rect.y: bar.height + 6

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.open = false
    }

    // Read notes from JSON
    Poller {
        id: notesPoller
        command: "cat ~/.config/quickshell/notes.json 2>/dev/null || echo '{}'"
        interval: 2000
        onValueChanged: {
            try { root.notesData = JSON.parse(value); } catch(e) { root.notesData = {}; }
        }
    }

    function saveNote(text) {
        if (!text.trim()) return;
        var copy = Object.assign({}, root.notesData);
        if (!copy[root.selectedDateStr]) copy[root.selectedDateStr] = [];
        copy[root.selectedDateStr].push(text.trim());
        root.notesData = copy;

        var json = JSON.stringify(copy).replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.config/quickshell && echo '" + json + "' > ~/.config/quickshell/notes.json"]);
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#1e1e2e"
        border.width: 1
        border.color: "#313244"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header: Time + Full Date
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2
                Text {
                    text: Qt.formatTime(new Date(), "hh:mm:ss AP")
                    color: "#cdd6f4"
                    font.pixelSize: 20
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: Qt.formatDate(new Date(), "dddd, MMMM dd, yyyy")
                    color: "#a6adc8"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Month / Year Nav
            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: "◀"
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1)
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                    color: "#cdd6f4"
                    font.bold: true
                }
                Button {
                    text: "▶"
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1)
                }
            }

            // Month Calendar
            MonthGrid {
                id: grid
                Layout.fillWidth: true
                month: root.viewDate.getMonth()
                year: root.viewDate.getFullYear()

                delegate: Rectangle {
                    implicitWidth: 36
                    implicitHeight: 32
                    radius: 6
                    property string cellDate: Qt.formatDate(model.date, "yyyy-MM-dd")
                    property bool isSelected: root.selectedDateStr === cellDate
                    property bool hasNotes: root.notesData[cellDate] && root.notesData[cellDate].length > 0

                    color: isSelected ? "#cba6f7" : (hasNotes ? "#45475a" : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        color: isSelected ? "#11111b" : (model.month === grid.month ? "#cdd6f4" : "#585b70")
                        font.bold: isSelected || hasNotes
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.selectedDateStr = parent.cellDate
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

            // Notes Section
            Text {
                text: "Notes for " + root.selectedDateStr + ":"
                color: "#f2cdcd"
                font.bold: true
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.notesData[root.selectedDateStr] || []
                delegate: Text {
                    text: "• " + modelData
                    color: "#cdd6f4"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    width: parent.width
                }
            }

            // Note Input
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: noteInput
                    Layout.fillWidth: true
                    placeholderText: "Add note..."
                    color: "#cdd6f4"
                    onAccepted: {
                        root.saveNote(text);
                        text = "";
                    }
                }
                Button {
                    text: "+"
                    onClicked: {
                        root.saveNote(noteInput.text);
                        noteInput.text = "";
                    }
                }
            }
        }
    }
}
