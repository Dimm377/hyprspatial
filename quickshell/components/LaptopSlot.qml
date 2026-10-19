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
        let baseY = parent.height - 22 - height;
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.laptopName !== "" ? root.laptopName : "Internal"
                    font.family: root.fontMono
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: root.isStandby
                        ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.4)
                        : (root.themeColors.text || "#e6e3d5")
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: {
                        if (root.isStandby) return "off";
                        if (root.previewMode === "extend") {
                            if (root.extendPosition === "right") return "left (0x0)";
                            if (root.extendPosition === "top") return "below (+1080y)";
                            return "right (+1920x0)";
                        }
                        return "primary (0x0)";
                    }
                    font.family: root.fontSans
                    font.pixelSize: 8
                    color: root.isStandby
                        ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.4)
                        : ((root.previewMode === "mirror") ? (root.themeColors.mauve || "#cacb77") : (root.themeColors.subtext0 || "#c9c7b6"))
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.isStandby ? "Standby" : (root.previewMode === "mirror" ? ((root.laptopRefresh || "60Hz") + " (Source)") : (root.laptopRefresh || "60Hz"))
                font.family: root.fontSans
                font.pixelSize: root.isStandby ? 10 : 13
                font.weight: Font.DemiBold
                color: root.isStandby
                    ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.6)
                    : (root.previewMode === "mirror" ? (root.themeColors.mauve || "#cacb77") : (root.themeColors.text || "#e6e3d5"))
            }

            Item { Layout.fillHeight: true }

            Text {
                text: root.laptopRes + (root.laptopRefresh !== "" ? (" (" + root.laptopRefresh + ")") : "")
                font.family: root.fontMono
                font.pixelSize: 8.5
                font.letterSpacing: 0.2
                color: root.isStandby
                    ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.6)
                    : Qt.alpha(root.themeColors.subtext1 || "#939182", 0.85)
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
