import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    color: "transparent"

    property var themeColors: ({})
    property string fontSans: "sans-serif"
    property string errorMessage: ""
    property int otherDisplays: 0

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: "Display Arrangement"
        font.family: root.fontSans
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: root.themeColors.text || "#e6e3d5"
    }

    // The cards already name each display and its mode; the header only carries exceptions
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Rectangle {
            visible: root.errorMessage !== ""
            implicitHeight: 24
            implicitWidth: errText.implicitWidth + 20
            radius: 12
            color: Qt.alpha(root.themeColors.peach || "#f38ba8", 0.15)
            border.width: 1
            border.color: Qt.alpha(root.themeColors.peach || "#f38ba8", 0.45)

            Text {
                id: errText
                anchors.centerIn: parent
                text: root.errorMessage
                font.family: root.fontSans
                font.pixelSize: 11
                font.weight: Font.Medium
                color: root.themeColors.peach || "#f38ba8"
            }
        }

        // hyprspatial manages one laptop panel + one external; say so when more are plugged in
        Text {
            visible: root.errorMessage === "" && root.otherDisplays > 0
            text: "+" + root.otherDisplays + " more, not managed"
            font.family: root.fontSans
            font.pixelSize: 11
            color: root.themeColors.subtext1 || "#939182"
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
