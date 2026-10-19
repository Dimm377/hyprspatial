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

    readonly property real lensX: x + width - 8
    readonly property real lensY: y + 25

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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: root.themeColors.green || "#c9c8a5"
                        }

                        Text {
                            text: "PROJECTOR"
                            font.family: root.fontSans
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: root.themeColors.mauve || "#cacb77"
                        }
                    }

                    Text {
                        text: root.extMonitorName !== "" ? root.extMonitorName : "External"
                        font.family: root.fontMono
                        font.pixelSize: 8
                        color: root.themeColors.text || "#e6e3d5"
                    }

                    Text {
                        text: "Mirror Duplicate"
                        font.family: root.fontSans
                        font.pixelSize: 8
                        color: root.themeColors.subtext1 || "#939182"
                    }
                }

                // Optical Lens Aperture
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.9)
                    border.width: 1.5
                    border.color: Qt.alpha(root.themeColors.mauve || "#cacb77", 0.5)

                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        radius: 6
                        color: Qt.alpha(root.themeColors.mauve || "#cacb77", 0.25)
                        border.width: 1
                        border.color: Qt.alpha(root.themeColors.mauve || "#cacb77", 0.45)
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
