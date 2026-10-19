import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: confirmWindow

    WlrLayershell.namespace: "display-switcher-confirm"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        return Math.round(val);
    }

    property int countdown: 15
    property int maxCountdown: 15
    property bool actionTaken: false

    readonly property string fontSans: "Google Sans, Adwaita Sans, Inter, Cantarell, Roboto, sans-serif"
    readonly property string fontMono: "CaskaydiaCove Nerd Font, CaskaydiaCove NF, monospace"

    property var themeColors: ({
        "base": "#0f0f07",
        "surface0": "#202018",
        "surface1": "#2b2a22",
        "surface2": "#36352c",
        "text": "#e6e3d5",
        "subtext0": "#c9c7b6",
        "subtext1": "#939182",
        "sapphire": "#74c7ec",
        "peach": "#f38ba8",
        "mauve": "#cacb77",
        "green": "#a6e3a1",
        "crust": "#14140c"
    })

    Process {
        id: colorProc
        command: ["bash", "-c", "cat ~/.local/state/serpantinum/qs_colors.json 2>/dev/null || cat ~/.local/state/serpantinum/qs_matugen_colors.json 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            id: colorOut
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(colorOut.text);
                    if (parsed && parsed.base) {
                        confirmWindow.themeColors = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: actionProc
        running: false
        onExited: Qt.quit()
    }

    function confirmKeep() {
        if (confirmWindow.actionTaken) return;
        confirmWindow.actionTaken = true;
        countdownTimer.stop();
        actionProc.command = [StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/hypr/scripts/toggle-presentation.sh", "--confirm"];
        actionProc.running = true;
    }

    function confirmRevert() {
        if (confirmWindow.actionTaken) return;
        confirmWindow.actionTaken = true;
        countdownTimer.stop();
        actionProc.command = [StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/hypr/scripts/toggle-presentation.sh", "--revert"];
        actionProc.running = true;
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (confirmWindow.countdown > 1) {
                confirmWindow.countdown--;
            } else {
                confirmWindow.countdown = 0;
                confirmRevert();
            }
        }
    }

    Shortcut { sequence: "Return"; onActivated: confirmKeep() }
    Shortcut { sequence: "Enter"; onActivated: confirmKeep() }
    Shortcut { sequence: "Escape"; onActivated: confirmRevert() }
    Shortcut { sequence: "k"; onActivated: confirmKeep() }
    Shortcut { sequence: "K"; onActivated: confirmKeep() }
    Shortcut { sequence: "r"; onActivated: confirmRevert() }
    Shortcut { sequence: "R"; onActivated: confirmRevert() }

    // Ambient dim
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.40)
        opacity: 0.0

        NumberAnimation on opacity {
            from: 0.0
            to: 1.0
            duration: 120
            easing.type: Easing.OutQuad
        }

        MouseArea {
            anchors.fill: parent
            onClicked: confirmKeep()
        }
    }

    // Centered Confirmation Dialog Container
    Item {
        id: dialogCard
        anchors.centerIn: parent
        implicitWidth: confirmWindow.s(410)
        implicitHeight: confirmWindow.s(156)
        width: implicitWidth
        height: implicitHeight

        scale: 0.98
        opacity: 0.0

        // Elevated Soft Drop Shadow Surface
        Rectangle {
            anchors.fill: parent
            radius: confirmWindow.s(10)
            color: confirmWindow.themeColors.base || "#0f0f07"
            border.width: 0

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.45
                shadowBlur: 0.8
                shadowVerticalOffset: confirmWindow.s(6)
                shadowHorizontalOffset: 0
            }
        }

        // Dialog Surface
        Rectangle {
            id: dialogCardSurface
            anchors.fill: parent
            radius: confirmWindow.s(10)
            color: Qt.alpha(confirmWindow.themeColors.base || "#0f0f07", 0.98)
            border.width: 0
            clip: true

        focus: true
        Component.onCompleted: dialogCard.forceActiveFocus()

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_K) {
                confirmKeep();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_R) {
                confirmRevert();
                event.accepted = true;
            }
        }

        ParallelAnimation {
            running: true
            NumberAnimation { target: dialogCard; property: "opacity"; from: 0.0; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: dialogCard; property: "scale"; from: 0.98; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: confirmWindow.s(18)
            spacing: confirmWindow.s(14)

            // Top Header: Title + Live Countdown Badge
            RowLayout {
                Layout.fillWidth: true
                spacing: confirmWindow.s(8)

                Text {
                    text: "Keep display settings?"
                    font.family: confirmWindow.fontSans
                    font.pixelSize: confirmWindow.s(14)
                    font.weight: Font.DemiBold
                    color: confirmWindow.themeColors.text || "#e6e3d5"
                }

                Item { Layout.fillWidth: true }

                // Countdown Pill
                Rectangle {
                    implicitWidth: timerLabel.implicitWidth + confirmWindow.s(14)
                    implicitHeight: confirmWindow.s(22)
                    radius: confirmWindow.s(11)
                    color: confirmWindow.countdown <= 5
                        ? Qt.alpha(confirmWindow.themeColors.peach || "#f38ba8", 0.18)
                        : Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.15)

                    Text {
                        id: timerLabel
                        anchors.centerIn: parent
                        text: confirmWindow.countdown + "s remaining"
                        font.family: confirmWindow.fontMono
                        font.pixelSize: confirmWindow.s(9.5)
                        font.weight: Font.Bold
                        color: confirmWindow.countdown <= 5
                            ? (confirmWindow.themeColors.peach || "#f38ba8")
                            : (confirmWindow.themeColors.mauve || "#cacb77")
                    }
                }
            }

            // Description Body
            Text {
                Layout.fillWidth: true
                text: "The new configuration will be automatically reverted if you do not confirm within 15 seconds."
                font.family: confirmWindow.fontSans
                font.pixelSize: confirmWindow.s(10.5)
                color: confirmWindow.themeColors.subtext0 || "#c9c7b6"
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: confirmWindow.s(8)

                Item { Layout.fillWidth: true }

                // Revert Button [Esc]
                Rectangle {
                    implicitHeight: confirmWindow.s(30)
                    implicitWidth: revertRow.implicitWidth + confirmWindow.s(20)
                    radius: confirmWindow.s(6)
                    color: revertMa.pressed
                        ? Qt.alpha(confirmWindow.themeColors.surface2 || "#36352c", 0.8)
                        : (revertMa.containsMouse
                            ? Qt.alpha(confirmWindow.themeColors.surface1 || "#2b2a22", 0.7)
                            : Qt.alpha(confirmWindow.themeColors.surface0 || "#202018", 0.6))

                    scale: revertMa.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    MouseArea {
                        id: revertMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: confirmWindow.confirmRevert()
                    }

                    RowLayout {
                        id: revertRow
                        anchors.centerIn: parent
                        spacing: confirmWindow.s(6)

                        Text {
                            text: "Revert"
                            font.family: confirmWindow.fontSans
                            font.pixelSize: confirmWindow.s(11)
                            font.weight: Font.Medium
                            color: confirmWindow.themeColors.subtext0 || "#c9c7b6"
                        }
                        Text {
                            text: "[Esc]"
                            font.family: confirmWindow.fontMono
                            font.pixelSize: confirmWindow.s(9)
                            color: confirmWindow.themeColors.subtext1 || "#939182"
                        }
                    }
                }

                // Keep Changes Button [Enter]
                Rectangle {
                    implicitHeight: confirmWindow.s(30)
                    implicitWidth: keepRow.implicitWidth + confirmWindow.s(22)
                    radius: confirmWindow.s(6)
                    color: keepMa.pressed
                        ? Qt.darker(confirmWindow.themeColors.mauve || "#cacb77", 1.15)
                        : (confirmWindow.themeColors.mauve || "#cacb77")

                    scale: keepMa.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    MouseArea {
                        id: keepMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: confirmWindow.confirmKeep()
                    }

                    RowLayout {
                        id: keepRow
                        anchors.centerIn: parent
                        spacing: confirmWindow.s(6)

                        Text {
                            text: "Keep Changes"
                            font.family: confirmWindow.fontSans
                            font.pixelSize: confirmWindow.s(11)
                            font.weight: Font.SemiBold
                            color: confirmWindow.themeColors.base || "#0f0f07"
                        }
                        Text {
                            text: "[↵]"
                            font.family: confirmWindow.fontMono
                            font.pixelSize: confirmWindow.s(9)
                            font.weight: Font.Bold
                            color: confirmWindow.themeColors.base || "#0f0f07"
                        }
                    }
                }
            }
        }
    }
}
}

