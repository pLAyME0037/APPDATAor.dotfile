import QtQuick
import QtQuick.Layouts

Rectangle {
    id:                            root
    property string icon:          ""
    property string label:         ""
    property color  iconColor:     "#89b4fa"
    property int    maxLabelWidth: 400
    implicitWidth:                 row.implicitWidth + 22
    implicitHeight:                25
    radius:                        height/2
    color:                         "#121218"
    RowLayout {
        id:                        row
        anchors.centerIn:          parent
        spacing:                   6
        Text {
            text:                  root.icon
            color:                 root.iconColor
            font.family:           "CaskaydiaMono Nerd Font Mono"
            font.pixelSize:        20
        }
        Text {
            text:                  root.label
            color:                 "#cdd6f4"
            font.family:           "CaskaydiaMono Nerd Font Mono"
            font.pixelSize:        15
            elide:                 Text.ElideRight
            Layout.maximumWidth:   root.maxLabelWidth
            visible:               root.label !== ""
        }
    }
}
