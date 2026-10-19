import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    color: "transparent"

    property var themeColors: ({})
    property string fontSans: "sans-serif"
    property string fontMono: "monospace"
    property string extMonitorName: ""
    property string extMonitorDesc: ""
    property string extMonitorRefresh: ""
    property string laptopName: ""
    property string laptopDesc: "Internal Display"
    property string laptopRefresh: ""
    property string errorMessage: ""

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: "Display Arrangement"
        font.family: root.fontSans
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: root.themeColors.text || "#e6e3d5"
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Error Alert Banner (visible on error)
        Rectangle {
            visible: root.errorMessage !== ""
            implicitHeight: 20
            implicitWidth: errPillLayout.implicitWidth + 16
            radius: 10
            color: Qt.alpha(root.themeColors.peach || "#f38ba8", 0.15)
            border.width: 1
            border.color: Qt.alpha(root.themeColors.peach || "#f38ba8", 0.45)

            RowLayout {
                id: errPillLayout
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "⚠ " + root.errorMessage
                    font.family: root.fontSans
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    color: root.themeColors.peach || "#f38ba8"
                }
            }
        }

        // Ambient subtle LED dot (visible when no error)
        Item {
            visible: root.errorMessage === ""
            width: 8
            height: 8

            Rectangle {
                anchors.centerIn: parent
                width: 5
                height: 5
                radius: 2.5
                color: root.extMonitorName !== ""
                    ? (root.themeColors.green || "#c9c8a5")
                    : (root.themeColors.subtext1 || "#939182")
            }
        }

        Text {
            visible: root.errorMessage === ""
            text: root.extMonitorName !== ""
                ? (root.extMonitorDesc + " • " + root.extMonitorRefresh)
                : (root.laptopDesc + " (" + root.laptopRefresh + " Only)")
            font.family: root.fontMono
            font.pixelSize: 10
            color: root.themeColors.subtext0 || "#c9c7b6"
            elide: Text.ElideRight
            Layout.maximumWidth: 260
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.35)
    }
}
