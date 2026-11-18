import QtQuick
import QtQuick.Layouts

Item {
    id: root
    width: 122
    height: 56
    anchors.horizontalCenter: parent.horizontalCenter

    property var themeColors: ({})
    property string fontSans: "sans-serif"
    property string fontMono: "monospace"
    property string previewMode: "mirror"
    property string extMonitorName: ""
    property string extMonitorLabel: ""

    readonly property real lensX: width - 8
    readonly property real lensY: 25

    y: (root.previewMode === "mirror") ? (parent.height - height) : (parent.height - height + 6)
    visible: opacity > 0.01
    opacity: (root.previewMode === "mirror") ? 1.0 : 0.0
    scale: (root.previewMode === "mirror") ? 1.0 : 0.92

    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Column {
        anchors.fill: parent
        spacing: 0

        // Projector Body
        Rectangle {
            id: projectorBody
            width: parent.width
            height: 50
            radius: 6
            color: Qt.alpha(root.themeColors.surface0 || "#202018", 0.95)
            border.width: 1
            border.color: Qt.alpha(root.themeColors.mauve || "#cacb77", 0.45)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Same reading order as the monitor cards: which display, then role
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: root.extMonitorLabel !== "" ? root.extMonitorLabel : "External"
                        font.family: root.fontSans
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        color: root.themeColors.subtext0 || "#c9c7b6"
                    }

                    Text {
                        text: "Mirrored"
                        font.family: root.fontSans
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: root.themeColors.mauve || "#cacb77"
                    }
                }

                // Optical Lens Aperture
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.95)
                    border.width: 1.5
                    border.color: (root.previewMode === "mirror")
                        ? (root.themeColors.mauve || "#cacb77")
                        : Qt.alpha(root.themeColors.mauve || "#cacb77", 0.5)

                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        radius: 6
                        color: (root.previewMode === "mirror")
                            ? Qt.alpha(root.themeColors.mauve || "#cacb77", 0.60)
                            : Qt.alpha(root.themeColors.mauve || "#cacb77", 0.25)
                        border.width: 1
                        border.color: (root.previewMode === "mirror")
                            ? (root.themeColors.text || "#e6e3d5")
                            : Qt.alpha(root.themeColors.mauve || "#cacb77", 0.45)
                    }
                }
            }
        }

        // Projector Feet Pads
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 80

            Rectangle {
                width: 10
                height: 3
                radius: 1
                color: Qt.alpha(root.themeColors.surface2 || "#36352c", 0.9)
            }
            Rectangle {
                width: 10
                height: 3
                radius: 1
                color: Qt.alpha(root.themeColors.surface2 || "#36352c", 0.9)
            }
        }
    }
}
