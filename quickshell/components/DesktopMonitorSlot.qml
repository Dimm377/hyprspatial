import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

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
    property string extMonitorLabel: ""
    property string extMonitorRes: "1920 × 1080"
    property string extMonitorRefresh: ""

    readonly property bool connected: root.extMonitorName !== ""
    readonly property bool isStandby: root.connected && root.previewMode === "laptop_only"

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

        // Nothing plugged in: an empty dashed slot, not a ghost monitor
        color: !root.connected
            ? "transparent"
            : (root.isStandby
                ? Qt.alpha(root.themeColors.crust || "#14140c", 0.8)
                : Qt.alpha(root.themeColors.surface0 || "#202018", 0.95))

        border.width: root.connected ? 1 : 0
        border.color: root.isStandby
            ? Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.4)
            : ((root.previewMode === "extend" || root.previewMode === "projector_only")
                ? Qt.alpha(root.themeColors.mauve || "#cacb77", 0.45)
                : Qt.alpha(root.themeColors.surface2 || "#36352c", 0.6))

        Shape {
            anchors.fill: parent
            visible: !root.connected
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.themeColors.surface2 || "#36352c"
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 3]
                fillColor: "transparent"
                PathRectangle { x: 0.5; y: 0.5; width: monitorScreen.width - 1; height: monitorScreen.height - 1; radius: 5 }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.connected
            text: "Plug in a display"
            font.family: root.fontSans
            font.pixelSize: 12
            color: root.themeColors.subtext1 || "#939182"
        }

        // Reading order: role in the arrangement (what you are deciding) > which display > mode
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 0
            visible: root.connected

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: root.extMonitorLabel !== "" ? root.extMonitorLabel : "External"
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
                    text: root.extMonitorName
                    font.family: root.fontMono
                    font.pixelSize: 10
                    color: root.themeColors.subtext1 || "#939182"
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: {
                    if (root.isStandby) return "Off";
                    if (root.previewMode === "projector_only") return "Main";
                    if (root.previewMode === "extend") {
                        if (root.extendPosition === "right") return "Right";
                        if (root.extendPosition === "top") return "Above";
                        return "Left";
                    }
                    return "Mirrored";
                }
                font.family: root.fontSans
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: root.isStandby
                    ? Qt.alpha(root.themeColors.subtext1 || "#939182", 0.6)
                    : (root.themeColors.mauve || "#cacb77")
            }

            Text {
                Layout.topMargin: 2
                visible: !root.isStandby
                text: root.extMonitorRes + (root.extMonitorRefresh !== "" ? " · " + root.extMonitorRefresh : "")
                font.family: root.fontMono
                font.pixelSize: 10
                color: root.themeColors.subtext1 || "#939182"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // 2. Monitor Stand Neck
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.connected ? 1 : 0
        width: 12
        height: 9
        color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.95)
        border.width: 1
        border.color: Qt.alpha(root.themeColors.surface2 || "#36352c", 0.6)
    }

    // 3. Monitor Stand Base
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.connected ? 1 : 0
        width: 54
        height: 3.5
        radius: 1.75
        color: Qt.alpha(root.themeColors.surface2 || "#36352c", 0.95)
        border.width: 1
        border.color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.8)
    }
}
