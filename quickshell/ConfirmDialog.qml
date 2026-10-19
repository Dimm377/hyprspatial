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

    readonly property string fontMono: "CaskaydiaCove Nerd Font, CaskaydiaCove NF, monospace"
    readonly property string fontSans: "CaskaydiaCove Nerd Font, CaskaydiaCove NF, sans-serif"

    property var themeColors: ({
        "base": "#0f0f07",
        "surface0": "#202018",
        "surface1": "#2b2a22",
        "surface2": "#36352c",
        "text": "#e6e3d5",
        "subtext0": "#c9c7b6",
        "subtext1": "#939182",
        "sapphire": "#484a00",
        "peach": "#f38ba8",
        "mauve": "#cacb77",
        "green": "#c9c8a5",
        "crust": "#14140c"
    })

    // Read colors from Serpantinum state
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

    // Dim Backdrop
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

    // Centered Confirmation Card
    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        implicitWidth: confirmWindow.s(410)
        implicitHeight: confirmWindow.s(170)
        width: implicitWidth
        height: implicitHeight
        radius: confirmWindow.s(12)
        color: Qt.alpha(confirmWindow.themeColors.base || "#0f0f07", 0.98)
        border.width: 1
        border.color: Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.35)
        clip: true

        scale: 0.96
        opacity: 0.0

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
            NumberAnimation { target: dialogCard; property: "opacity"; from: 0.0; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: dialogCard; property: "scale"; from: 0.96; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: confirmWindow.s(16)
            spacing: confirmWindow.s(12)

            // Header Row: Icon + Title + Countdown Pill
            RowLayout {
                Layout.fillWidth: true
                spacing: confirmWindow.s(8)

                // Status indicator
                Item {
                    width: confirmWindow.s(20)
                    height: confirmWindow.s(20)

                    Rectangle {
                        anchors.fill: parent
                        radius: confirmWindow.s(5)
                        color: confirmWindow.countdown <= 5
                            ? Qt.alpha(confirmWindow.themeColors.peach || "#f38ba8", 0.15)
                            : Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.12)
                        border.width: 1
                        border.color: confirmWindow.countdown <= 5
                            ? Qt.alpha(confirmWindow.themeColors.peach || "#f38ba8", 0.5)
                            : Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.4)

                        // Inner pulsing core LED
                        Rectangle {
                            anchors.centerIn: parent
                            width: confirmWindow.s(6)
                            height: confirmWindow.s(6)
                            radius: confirmWindow.s(3)
                            color: confirmWindow.countdown <= 5
                                ? (confirmWindow.themeColors.peach || "#f38ba8")
                                : (confirmWindow.themeColors.mauve || "#cacb77")

                            SequentialAnimation on opacity {
                                running: true
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.4; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 1.0; to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }

                Text {
                    text: "Keep Display Settings?"
                    font.family: confirmWindow.fontSans
                    font.pixelSize: confirmWindow.s(14)
                    font.weight: Font.DemiBold
                    color: confirmWindow.themeColors.text || "#e6e3d5"
                }

                Item { Layout.fillWidth: true }

                // Remaining Seconds Countdown Pill
                Rectangle {
                    implicitWidth: timerPillLayout.implicitWidth + confirmWindow.s(12)
                    implicitHeight: confirmWindow.s(22)
                    radius: confirmWindow.s(11)
                    color: confirmWindow.countdown <= 5
                        ? Qt.alpha(confirmWindow.themeColors.peach || "#f38ba8", 0.2)
                        : Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.15)
                    border.width: 1
                    border.color: confirmWindow.countdown <= 5
                        ? Qt.alpha(confirmWindow.themeColors.peach || "#f38ba8", 0.5)
                        : Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.4)

                    RowLayout {
                        id: timerPillLayout
                        anchors.centerIn: parent
                        spacing: confirmWindow.s(4)

                        Text {
                            text: confirmWindow.countdown + "s"
                            font.family: confirmWindow.fontMono
                            font.pixelSize: confirmWindow.s(10)
                            font.weight: Font.Bold
                            color: confirmWindow.countdown <= 5
                                ? (confirmWindow.themeColors.peach || "#f38ba8")
                                : (confirmWindow.themeColors.mauve || "#cacb77")
                        }
                    }
                }
            }

            // Description
            Text {
                Layout.fillWidth: true
                text: "Reverting automatically to previous layout in " + confirmWindow.countdown + " seconds if unconfirmed."
                font.family: confirmWindow.fontSans
                font.pixelSize: confirmWindow.s(10.5)
                color: confirmWindow.themeColors.subtext0 || "#c9c7b6"
                wrapMode: Text.WordWrap
            }

            // Animated Countdown Progress Bar Track
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: confirmWindow.s(4)
                radius: confirmWindow.s(2)
                color: Qt.alpha(confirmWindow.themeColors.surface1 || "#2b2a22", 0.6)

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: parent.width * (confirmWindow.countdown / confirmWindow.maxCountdown)
                    radius: confirmWindow.s(2)
                    color: confirmWindow.countdown <= 5
                        ? (confirmWindow.themeColors.peach || "#f38ba8")
                        : (confirmWindow.themeColors.mauve || "#cacb77")

                    Behavior on width {
                        NumberAnimation {
                            duration: 950
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons Row
            RowLayout {
                Layout.fillWidth: true
                spacing: confirmWindow.s(10)

                // 1. Revert Button (Esc)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: confirmWindow.s(32)
                    radius: confirmWindow.s(6)
                    scale: revertMa.pressed ? 0.98 : (revertMa.containsMouse ? 1.01 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    color: revertMa.pressed
                        ? Qt.alpha(confirmWindow.themeColors.surface2 || "#36352c", 0.95)
                        : (revertMa.containsMouse
                            ? Qt.alpha(confirmWindow.themeColors.surface2 || "#36352c", 0.75)
                            : Qt.alpha(confirmWindow.themeColors.surface1 || "#2b2a22", 0.6))
                    border.width: 1
                    border.color: Qt.alpha(confirmWindow.themeColors.surface2 || "#36352c", 0.8)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: confirmWindow.s(6)

                        Text {
                            text: "Revert Now"
                            font.family: confirmWindow.fontSans
                            font.pixelSize: confirmWindow.s(11)
                            font.weight: Font.Medium
                            color: confirmWindow.themeColors.subtext0 || "#c9c7b6"
                        }

                        Rectangle {
                            width: confirmWindow.s(24)
                            height: confirmWindow.s(16)
                            radius: confirmWindow.s(3)
                            color: Qt.alpha(confirmWindow.themeColors.surface0 || "#202018", 0.8)
                            border.width: 1
                            border.color: Qt.alpha(confirmWindow.themeColors.surface2 || "#36352c", 0.6)
                            Text {
                                anchors.centerIn: parent
                                text: "Esc"
                                font.family: confirmWindow.fontMono
                                font.pixelSize: confirmWindow.s(8)
                                color: confirmWindow.themeColors.subtext1 || "#939182"
                            }
                        }
                    }

                    MouseArea {
                        id: revertMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: confirmRevert()
                    }
                }

                // 2. Keep Changes Button (Enter)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: confirmWindow.s(32)
                    radius: confirmWindow.s(6)
                    scale: keepMa.pressed ? 0.98 : (keepMa.containsMouse ? 1.01 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    color: keepMa.pressed
                        ? Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.35)
                        : (keepMa.containsMouse
                            ? Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.25)
                            : Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.16))
                    border.width: 1
                    border.color: Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.5)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: confirmWindow.s(6)

                        Text {
                            text: "Keep Changes"
                            font.family: confirmWindow.fontSans
                            font.pixelSize: confirmWindow.s(11)
                            font.weight: Font.DemiBold
                            color: confirmWindow.themeColors.mauve || "#cacb77"
                        }

                        Rectangle {
                            width: confirmWindow.s(22)
                            height: confirmWindow.s(16)
                            radius: confirmWindow.s(3)
                            color: Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.25)
                            border.width: 1
                            border.color: Qt.alpha(confirmWindow.themeColors.mauve || "#cacb77", 0.45)
                            Text {
                                anchors.centerIn: parent
                                text: "↵"
                                font.family: confirmWindow.fontMono
                                font.pixelSize: confirmWindow.s(9)
                                font.weight: Font.Bold
                                color: confirmWindow.themeColors.mauve || "#cacb77"
                            }
                        }
                    }

                    MouseArea {
                        id: keepMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: confirmKeep()
                    }
                }
            }
        }
    }
}
