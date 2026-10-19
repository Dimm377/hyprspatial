import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    color: "transparent"

    property var themeColors: ({})
    property string fontSans: "sans-serif"
    property string fontMono: "monospace"
    property var modesList: []
    property string currentMode: "extend"
    property int selectedIndex: 0
    property bool applyingMode: false
    property string extendPosition: "left"
    property string extMonitorName: ""

    signal modeSelected(string arg, int index)
    signal modeHovered(string modeId, int index)
    signal cycleExtendPositionRequested()

    function getModeDesc(item) {
        if (item.modeId === "extend") {
            if (root.extendPosition === "right") return "Laptop on left (0x0) · External on right (+1920x0)";
            if (root.extendPosition === "top") return "External on top (0x0) · Laptop below (+1080y)";
            return "External on left (0x0) · Laptop on right (+1920x0)";
        }
        return item.desc;
    }

    Item {
        id: presetArea
        anchors.fill: parent
        anchors.margins: 10

        // Smooth Sliding Selection Indicator
        Rectangle {
            id: focusIndicator
            z: 0
            x: 0
            width: presetArea.width
            readonly property real rowHeight: (root.modesList.length > 0)
                ? (presetArea.height - (root.modesList.length - 1) * 4) / root.modesList.length
                : 40
            height: rowHeight
            y: root.selectedIndex * (rowHeight + 4)
            radius: 6
            color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.70)
            border.width: 1
            border.color: Qt.alpha(root.themeColors.mauve || "#cacb77", 0.45)

            Behavior on y {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        ColumnLayout {
            id: presetColumn
            z: 1
            anchors.fill: parent
            spacing: 4

            Repeater {
                model: root.modesList

                delegate: Item {
                    id: presetItem
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property bool isCurrent: (root.currentMode === modelData.modeId)
                    readonly property bool isFocused: (root.selectedIndex === index)
                    readonly property bool isHovered: itemMa.containsMouse
                    readonly property bool isAvailable: (modelData.modeId === "laptop_only" || root.extMonitorName !== "")

                    opacity: isAvailable ? 1.0 : 0.42
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    scale: itemMa.pressed ? 0.985 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    // Active indicator tick on left edge
                    Rectangle {
                        visible: presetItem.isCurrent
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 2.5
                        radius: 1.25
                        color: root.themeColors.mauve || "#cacb77"
                    }

                    RowLayout {
                        z: 1
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        // Keycap Badge (Monospace font for numbers)
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 4
                            color: presetItem.isCurrent
                                ? Qt.alpha(root.themeColors.mauve || "#cacb77", 0.20)
                                : Qt.alpha(root.themeColors.surface0 || "#202018", 0.90)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.key
                                font.family: root.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: presetItem.isCurrent
                                    ? (root.themeColors.mauve || "#cacb77")
                                    : (root.themeColors.text || "#e6e3d5")
                            }
                        }

                        // Mode Title & Description (Human Sans-Serif)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 5

                                Rectangle {
                                    visible: root.applyingMode && presetItem.isFocused
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: root.themeColors.mauve || "#cacb77"

                                    SequentialAnimation on opacity {
                                        running: root.applyingMode && presetItem.isFocused
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.2; to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 1.0; to: 0.2; duration: 350; easing.type: Easing.InOutQuad }
                                    }
                                }

                                Text {
                                    text: (root.applyingMode && presetItem.isFocused)
                                        ? "Applying…"
                                        : modelData.title
                                    font.family: root.fontSans
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: (root.applyingMode && presetItem.isFocused)
                                        ? (root.themeColors.mauve || "#cacb77")
                                        : ((presetItem.isHovered || presetItem.isFocused || presetItem.isCurrent)
                                            ? (root.themeColors.text || "#e6e3d5")
                                            : (root.themeColors.subtext0 || "#c9c7b6"))
                                }
                            }

                            Text {
                                text: !presetItem.isAvailable ? "External display disconnected" : root.getModeDesc(modelData)
                                font.family: root.fontSans
                                font.pixelSize: 10
                                font.weight: Font.Normal
                                color: !presetItem.isAvailable
                                    ? Qt.alpha(root.themeColors.peach || "#f38ba8", 0.7)
                                    : (root.themeColors.subtext1 || "#939182")
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Interactive Position Swap Chip (for Extend Desktop mode)
                        Rectangle {
                            id: posChip
                            visible: modelData.modeId === "extend" && presetItem.isAvailable
                            implicitHeight: 20
                            implicitWidth: posChipLayout.implicitWidth + 12
                            radius: 4
                            scale: posChipMa.pressed ? 0.94 : (posChipMa.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            color: posChipMa.pressed
                                ? Qt.alpha(root.themeColors.mauve || "#cacb77", 0.25)
                                : (presetItem.isFocused
                                    ? Qt.alpha(root.themeColors.surface2 || "#36352c", 0.95)
                                    : Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.75))

                            RowLayout {
                                id: posChipLayout
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "⇄"
                                    font.family: root.fontMono
                                    font.pixelSize: 9
                                    color: root.themeColors.mauve || "#cacb77"
                                }
                                Text {
                                    text: {
                                        if (root.extendPosition === "right") return "EXT ON RIGHT";
                                        if (root.extendPosition === "top") return "EXT ON TOP";
                                        return "EXT ON LEFT";
                                    }
                                    font.family: root.fontMono
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                    color: root.themeColors.text || "#e6e3d5"
                                }
                            }

                            MouseArea {
                                id: posChipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.cycleExtendPositionRequested()
                            }
                        }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            root.modeHovered(modelData.modeId, index);
                        }
                        onClicked: {
                            root.modeSelected(modelData.arg, index);
                        }
                    }
                }
            }
        }
    }
}
