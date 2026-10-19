import QtQuick
import QtQuick.Layouts

Column {
    id: root
    width: 158
    height: 102.5
    transformOrigin: Item.Center
    spacing: 0

    property var themeColors: ({})
    property string fontSans: "sans-serif"
    property string fontMono: "monospace"
    property string previewMode: "extend"
    property string extendPosition: "left"
    property string extMonitorName: ""
    property string extMonitorRes: "1920 × 1080"
    property string extMonitorRefresh: ""

    readonly property bool isStandby: (root.previewMode === "laptop_only")

    y: isStandby ? (parent.height - height + 4) : (parent.height - height)
    visible: opacity > 0.01
    opacity: (root.previewMode === "mirror") ? 0.0 : (isStandby ? 0.25 : 1.0)
    scale: {
        if (root.previewMode === "mirror") return 0.92;
        if (isStandby) return 0.97;
        if (root.previewMode === "extend" && root.extendPosition === "top") return 0.82;
        return 1.0;
    }

    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // 1. Monitor Screen Panel
    Rectangle {
        id: monitorScreen
        width: 158
        height: 90
        radius: 5

        color: root.isStandby
            ? Qt.alpha(root.themeColors.crust || "#14140c", 0.8)
            : Qt.alpha(root.themeColors.surface0 || "#202018", 0.95)

        border.width: 1
        border.color: root.isStandby
            ? Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.4)
            : ((root.previewMode === "extend" || root.previewMode === "projector_only")
                ? Qt.alpha(root.themeColors.mauve || "#cacb77", 0.45)
                : Qt.alpha(root.themeColors.surface2 || "#36352c", 0.6))

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.extMonitorName !== "" ? root.extMonitorName : "External"
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
                        if (root.previewMode === "projector_only") return "primary (0x0)";
                        if (root.previewMode === "extend") {
                            if (root.extendPosition === "right") return "right (+1920x0)";
                            if (root.extendPosition === "top") return "top (0x0)";
                            return "left (0x0)";
                        }
                        return "external";
                    }
                    font.family: root.fontSans
                    font.pixelSize: 8
                    color: root.isStandby
                        ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.4)
                        : (root.themeColors.mauve || "#cacb77")
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.isStandby ? "Standby" : (root.extMonitorRefresh !== "" ? root.extMonitorRefresh : "Active")
                font.family: root.fontSans
                font.pixelSize: root.isStandby ? 10 : 13
                font.weight: Font.DemiBold
                color: root.isStandby
                    ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.6)
                    : (root.themeColors.mauve || "#cacb77")
            }

            Item { Layout.fillHeight: true }

            Text {
                text: root.extMonitorRes + (root.extMonitorRefresh !== "" ? (" (" + root.extMonitorRefresh + ")") : "")
                font.family: root.fontMono
                font.pixelSize: 9
                font.letterSpacing: 0.2
                color: root.isStandby
                    ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.6)
                    : Qt.alpha(root.themeColors.subtext1 || "#939182", 0.85)
            }
        }
    }

    // 2. Monitor Stand Neck
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 12
        height: 9
        color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.95)
        border.width: 1
        border.color: Qt.alpha(root.themeColors.surface2 || "#36352c", 0.6)
    }

    // 3. Monitor Stand Base
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 54
        height: 3.5
        radius: 1.75
        color: Qt.alpha(root.themeColors.surface2 || "#36352c", 0.95)
        border.width: 1
        border.color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.8)
    }
}
