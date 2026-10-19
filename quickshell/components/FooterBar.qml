import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 32
    color: "transparent"

    property var themeColors: ({})
    property string fontSans: "sans-serif"
    property string fontMono: "monospace"

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.25)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        RowLayout {
            spacing: 4
            Text {
                text: "1-4"
                font.family: root.fontMono
                font.pixelSize: 9
                font.weight: Font.Bold
                color: root.themeColors.subtext0 || "#c9c7b6"
            }
            Text {
                text: "Select"
                font.family: root.fontSans
                font.pixelSize: 9
                color: root.themeColors.subtext1 || "#939182"
            }
        }

        Text {
            text: "·"
            font.pixelSize: 9
            color: root.themeColors.surface2 || "#36352c"
        }

        RowLayout {
            spacing: 4
            Text {
                text: "S / Tab"
                font.family: root.fontMono
                font.pixelSize: 9
                font.weight: Font.Bold
                color: root.themeColors.subtext0 || "#c9c7b6"
            }
            Text {
                text: "Swap Position"
                font.family: root.fontSans
                font.pixelSize: 9
                color: root.themeColors.subtext1 || "#939182"
            }
        }

        Text {
            text: "·"
            font.pixelSize: 9
            color: root.themeColors.surface2 || "#36352c"
        }

        RowLayout {
            spacing: 4
            Text {
                text: "↵"
                font.family: root.fontMono
                font.pixelSize: 9
                font.weight: Font.Bold
                color: root.themeColors.subtext0 || "#c9c7b6"
            }
            Text {
                text: "Apply"
                font.family: root.fontSans
                font.pixelSize: 9
                color: root.themeColors.subtext1 || "#939182"
            }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: 4
            Text {
                text: "Esc"
                font.family: root.fontMono
                font.pixelSize: 9
                font.weight: Font.Bold
                color: root.themeColors.subtext0 || "#c9c7b6"
            }
            Text {
                text: "Close"
                font.family: root.fontSans
                font.pixelSize: 9
                color: root.themeColors.subtext1 || "#939182"
            }
        }
    }
}
