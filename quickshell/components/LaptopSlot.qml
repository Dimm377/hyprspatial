import QtQuick
import QtQuick.Layouts

Column {
    id: root
    width: 148
    height: 84.5
    transformOrigin: Item.Center
    spacing: 1

    property var themeColors: ({})
    property string fontSans: "sans-serif"
    property string fontMono: "monospace"
    property string previewMode: "extend"
    property string extendPosition: "left"
    property real deskY: parent.height - 22
    property string laptopName: ""
    property string laptopRes: "1920 × 1080"
    property string laptopRefresh: ""

    readonly property bool isStandby: (root.previewMode === "projector_only")

    // Geometry properties for projection beam target calculation
    readonly property real screenTargetX: x + (width - laptopScreen.width) / 2
    readonly property real screenCenterY: y + laptopScreen.y + (laptopScreen.height / 2)
    readonly property real screenHalfHeight: laptopScreen.height / 2

    x: {
        if (root.previewMode === "extend") {
            if (root.extendPosition === "right") {
                return 16;
            } else if (root.extendPosition === "top") {
                return Math.round((parent.width - width) / 2);
            } else {
                return parent.width - width - 16;
            }
        }
        return (root.previewMode === "laptop_only")
            ? (parent.width - width - 22)
            : (parent.width - width - 16);
    }

    y: {
        let baseY = root.deskY - height;
        if (root.previewMode === "extend" && root.extendPosition === "top") {
            return baseY + 2;
        }
        return baseY + (isStandby ? 4 : 0);
    }

    opacity: isStandby ? 0.25 : 1.0
    scale: {
        if (isStandby) return 0.97;
        if (root.previewMode === "extend" && root.extendPosition === "top") return 0.84;
        return 1.0;
    }

    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // 1. Laptop Screen Lid
    Rectangle {
        id: laptopScreen
        anchors.horizontalCenter: parent.horizontalCenter
        width: 138
        height: 78
        radius: 4

        color: root.isStandby
            ? Qt.alpha(root.themeColors.crust || "#14140c", 0.8)
            : Qt.alpha(root.themeColors.surface0 || "#202018", 0.95)

        border.width: 1
        border.color: root.isStandby
            ? Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.4)
            : ((root.previewMode === "laptop_only" || root.previewMode === "mirror")
                ? Qt.alpha(root.themeColors.mauve || "#cacb77", 0.45)
                : Qt.alpha(root.themeColors.surface2 || "#36352c", 0.6))

        // Same reading order as the external monitor card: role > which display > mode
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: "Laptop"
                    font.family: root.fontSans
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    color: root.isStandby
                        ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.5)
                        : (root.themeColors.subtext0 || "#c9c7b6")
                }
                Text {
                    text: root.laptopName
                    font.family: root.fontMono
                    font.pixelSize: 10
                    color: root.themeColors.subtext1 || "#939182"
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: {
                    if (root.isStandby) return "Off";
                    if (root.previewMode === "mirror") return "Source";
                    if (root.previewMode === "extend") {
                        if (root.extendPosition === "right") return "Left";
                        if (root.extendPosition === "top") return "Below";
                        return "Right";
                    }
                    return "Main";
                }
                font.family: root.fontSans
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: root.isStandby
                    ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.6)
                    : (root.previewMode === "mirror" ? (root.themeColors.mauve || "#cacb77") : (root.themeColors.text || "#e6e3d5"))
            }

            Text {
                Layout.topMargin: 2
                visible: !root.isStandby
                text: root.laptopRes + (root.laptopRefresh !== "" ? " · " + root.laptopRefresh : "")
                font.family: root.fontMono
                font.pixelSize: 10
                color: root.themeColors.subtext1 || "#939182"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // 2. Laptop Keyboard Chassis & Touchpad Notch
    Rectangle {
        id: laptopChassis
        anchors.horizontalCenter: parent.horizontalCenter
        width: 150
        height: 6
        radius: 2
        color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.95)
        border.width: 1
        border.color: Qt.alpha(root.themeColors.surface2 || "#36352c", 0.7)

        // Touchpad Notch
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 24
            height: 2
            radius: 1
            color: Qt.alpha(root.themeColors.surface2 || "#36352c", 0.9)
        }
    }
}
