import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "components"

PanelWindow {
    id: window

    WlrLayershell.namespace: "display-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property string extMonitorName: ""
    property string extMonitorDesc: ""
    property string extMonitorRefresh: ""
    property string extMonitorRes: "1920 × 1080"
    property string laptopName: ""
    property string laptopDesc: "Internal Display"
    property string laptopRefresh: ""
    property string laptopRes: "1920 × 1080"
    property string extendPosition: "left"
    property string currentMode: "extend"
    property string previewMode: currentMode
    property int selectedIndex: 0
    property bool applyingMode: false
    property string errorMessage: ""

    // Typography: Human Sans-Serif for titles and descriptions, Monospace for keycaps & technical data
    readonly property string fontSans: "Google Sans, Adwaita Sans, Inter, Cantarell, Roboto, sans-serif"
    readonly property string fontMono: "CaskaydiaCove Nerd Font, CaskaydiaCove NF, monospace"

    readonly property var modesList: [
        {
            modeId: "laptop_only",
            arg: "--laptop-only",
            key: "1",
            title: "Laptop Screen Only",
            desc: "Internal display only · external powered off"
        },
        {
            modeId: "mirror",
            arg: "--mirror",
            key: "2",
            title: "Mirror Display",
            desc: "Duplicate laptop screen onto external display"
        },
        {
            modeId: "extend",
            arg: "--extend",
            key: "3",
            title: "Extend Desktop",
            desc: "External on left (0x0) · Laptop on right (+1920x0)"
        },
        {
            modeId: "projector_only",
            arg: "--projector-only",
            key: "4",
            title: "External Monitor Only",
            desc: "External display only · laptop screen powered off"
        }
    ]

    property var themeColors: ({
        "base": "#0f0f07",
        "surface0": "#202018",
        "surface1": "#2b2a22",
        "surface2": "#36352c",
        "text": "#e6e3d5",
        "subtext0": "#c9c7b6",
        "subtext1": "#939182",
        "sapphire": "#484a00",
        "peach": "#a4d0be",
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
                        window.themeColors = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    // Detect monitors
    Process {
        id: detectProc
        command: ["bash", "-c", "hyprctl monitors all -j 2>/dev/null || hyprctl monitors -j 2>/dev/null || echo '[]'"]
        running: true
        stdout: StdioCollector {
            id: detectOut
            onStreamFinished: {
                try {
                    let raw = detectOut.text.trim();
                    if (!raw) return;
                    let mons = JSON.parse(raw);
                    let ext = null;
                    let laptop = null;

                    // Dynamically detect internal laptop display first
                    for (let i = 0; i < mons.length; i++) {
                        let m = mons[i];
                        if (/^(eDP|LVDS|DSI)/.test(m.name)) {
                            laptop = m;
                            break;
                        }
                    }
                    if (!laptop && mons.length > 0) {
                        laptop = mons[0];
                    }

                    // Dynamically detect external display (first monitor that is not laptop)
                    for (let i = 0; i < mons.length; i++) {
                        let m = mons[i];
                        if (laptop && m.name !== laptop.name) {
                            ext = m;
                            break;
                        }
                    }

                    if (laptop) {
                        window.laptopName = laptop.name;
                        if (laptop.width && laptop.height) {
                            window.laptopRes = laptop.width + " × " + laptop.height;
                        }
                        if (laptop.refreshRate) {
                            window.laptopRefresh = Math.round(laptop.refreshRate) + "Hz";
                        }
                        if (laptop.make) {
                            window.laptopDesc = laptop.make + (laptop.model ? (" " + laptop.model) : "");
                        } else if (laptop.model) {
                            window.laptopDesc = laptop.model;
                        } else {
                            window.laptopDesc = "Internal Display";
                        }
                    }
                    if (ext) {
                        window.extMonitorName = ext.name;
                        window.extMonitorDesc = (ext.make ? (ext.make + " " + (ext.model || ext.name)) : (ext.model || ext.description || ext.name));
                        window.extMonitorRefresh = ext.refreshRate ? (Math.round(ext.refreshRate) + "Hz") : "";
                        if (ext.width && ext.height) {
                            window.extMonitorRes = ext.width + " × " + ext.height;
                        }
                        let isMirror = (ext.mirrorOf && ext.mirrorOf !== "none");
                        let extDisabled = ext.disabled;
                        let laptopDisabled = laptop ? laptop.disabled : false;

                        if (extDisabled) {
                            window.currentMode = "laptop_only";
                        } else if (laptopDisabled) {
                            window.currentMode = "projector_only";
                        } else if (isMirror) {
                            window.currentMode = "mirror";
                        } else {
                            window.currentMode = "extend";
                            // Dynamically detect current layout orientation
                            if (ext.y < laptop.y) {
                                window.extendPosition = "top";
                            } else if (ext.x > laptop.x) {
                                window.extendPosition = "right";
                            } else {
                                window.extendPosition = "left";
                            }
                        }
                    } else {
                        window.extMonitorName = "";
                        window.extMonitorDesc = "Disconnected";
                        window.extMonitorRefresh = "";
                        window.currentMode = "laptop_only";
                    }
                    window.previewMode = window.currentMode;

                    for (let j = 0; j < window.modesList.length; j++) {
                        if (window.modesList[j].modeId === window.currentMode) {
                            window.selectedIndex = j;
                            break;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: applyProc
        running: false
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: (exitCode, exitStatus) => {
            applyTimeoutTimer.stop();
            if (exitCode === 0) {
                settleTimer.restart();
            } else {
                window.applyingMode = false;
                let errMsg = applyErr.text.trim();
                window.errorMessage = errMsg ? errMsg : ("Failed to switch mode (exit " + exitCode + ")");
                errorTimer.restart();
            }
        }
    }

    Timer {
        id: settleTimer
        interval: 120
        repeat: false
        onTriggered: closeWindow()
    }

    Timer {
        id: applyTimeoutTimer
        interval: 3500
        repeat: false
        onTriggered: {
            if (window.applyingMode) {
                closeWindow();
            }
        }
    }

    Timer {
        id: errorTimer
        interval: 4000
        repeat: false
        onTriggered: {
            window.errorMessage = "";
        }
    }

    function cycleExtendPosition() {
        if (window.extendPosition === "left") {
            window.extendPosition = "right";
        } else if (window.extendPosition === "right") {
            window.extendPosition = "top";
        } else {
            window.extendPosition = "left";
        }
        window.previewMode = "extend";
        for (let j = 0; j < window.modesList.length; j++) {
            if (window.modesList[j].modeId === "extend") {
                window.selectedIndex = j;
                break;
            }
        }
    }

    function selectMode(arg) {
        if (window.applyingMode) return;
        if (arg !== "--laptop-only" && window.extMonitorName === "") {
            window.errorMessage = "External display disconnected";
            errorTimer.restart();
            return;
        }
        window.errorMessage = "";
        window.applyingMode = true;
        applyTimeoutTimer.restart();
        if (arg === "--extend") {
            applyProc.command = [StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/hypr/scripts/toggle-presentation.sh", "--extend", window.extendPosition];
        } else {
            applyProc.command = [StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/hypr/scripts/toggle-presentation.sh", arg];
        }
        applyProc.running = true;
    }

    function closeWindow() {
        exitAnim.restart();
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: mainCard; property: "opacity"; to: 0.0; duration: 90; easing.type: Easing.InCubic }
            NumberAnimation { target: mainCard; property: "scale"; to: 0.98; duration: 90; easing.type: Easing.InCubic }
            NumberAnimation { target: backdropDim; property: "opacity"; to: 0.0; duration: 100; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: Qt.quit()
        }
    }

    function selectModeByKey(keyStr) {
        for (let i = 0; i < window.modesList.length; i++) {
            if (window.modesList[i].key === keyStr) {
                window.selectedIndex = i;
                window.previewMode = window.modesList[i].modeId;
                selectMode(window.modesList[i].arg);
                break;
            }
        }
    }

    // Direct hotkeys
    Shortcut { sequence: "1"; onActivated: selectModeByKey("1") }
    Shortcut { sequence: "2"; onActivated: selectModeByKey("2") }
    Shortcut { sequence: "3"; onActivated: selectModeByKey("3") }
    Shortcut { sequence: "4"; onActivated: selectModeByKey("4") }
    Shortcut { sequence: "s"; onActivated: window.cycleExtendPosition() }
    Shortcut { sequence: "S"; onActivated: window.cycleExtendPosition() }
    Shortcut { sequence: "Tab"; onActivated: window.cycleExtendPosition() }
    Shortcut { sequence: "Backtab"; onActivated: window.cycleExtendPosition() }
    Shortcut { sequence: "Escape"; onActivated: closeWindow() }

    Shortcut {
        sequence: "Up"
        onActivated: {
            window.selectedIndex = (window.selectedIndex - 1 + window.modesList.length) % window.modesList.length;
            window.previewMode = window.modesList[window.selectedIndex].modeId;
        }
    }
    Shortcut {
        sequence: "Down"
        onActivated: {
            window.selectedIndex = (window.selectedIndex + 1) % window.modesList.length;
            window.previewMode = window.modesList[window.selectedIndex].modeId;
        }
    }
    Shortcut {
        sequence: "Return"
        onActivated: {
            if (window.selectedIndex >= 0 && window.selectedIndex < window.modesList.length) {
                selectMode(window.modesList[window.selectedIndex].arg);
            }
        }
    }

    // Dim Backdrop
    Rectangle {
        id: backdropDim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: 0.0

        NumberAnimation on opacity {
            from: 0.0
            to: 1.0
            duration: 140
            easing.type: Easing.OutQuad
        }

        MouseArea {
            anchors.fill: parent
            onClicked: window.closeWindow()
        }
    }

    // Main Studio Card
    Rectangle {
        id: mainCard
        anchors.centerIn: parent
        implicitWidth: 740
        implicitHeight: 330
        width: implicitWidth
        height: implicitHeight
        radius: 12
        color: Qt.alpha(window.themeColors.base || "#0f0f07", 0.98)
        border.width: 1
        border.color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.65)
        clip: true

        scale: 0.98
        opacity: 0.0

        focus: true
        Component.onCompleted: mainCard.forceActiveFocus()

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_1) {
                selectModeByKey("1");
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                selectModeByKey("2");
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                selectModeByKey("3");
                event.accepted = true;
            } else if (event.key === Qt.Key_4) {
                selectModeByKey("4");
                event.accepted = true;
            } else if (event.key === Qt.Key_S || event.text === "s" || event.text === "S" || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                window.cycleExtendPosition();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                closeWindow();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                window.selectedIndex = (window.selectedIndex - 1 + window.modesList.length) % window.modesList.length;
                window.previewMode = window.modesList[window.selectedIndex].modeId;
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                window.selectedIndex = (window.selectedIndex + 1) % window.modesList.length;
                window.previewMode = window.modesList[window.selectedIndex].modeId;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (window.selectedIndex >= 0 && window.selectedIndex < window.modesList.length) {
                    selectMode(window.modesList[window.selectedIndex].arg);
                }
                event.accepted = true;
            }
        }

        ParallelAnimation {
            running: true
            NumberAnimation { target: mainCard; property: "opacity"; from: 0.0; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: mainCard; property: "scale"; from: 0.98; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 1. Header Bar
            HeaderBar {
                themeColors: window.themeColors
                fontSans: window.fontSans
                fontMono: window.fontMono
                extMonitorName: window.extMonitorName
                extMonitorDesc: window.extMonitorDesc
                extMonitorRefresh: window.extMonitorRefresh
                laptopName: window.laptopName
                laptopDesc: window.laptopDesc
                laptopRefresh: window.laptopRefresh
                errorMessage: window.errorMessage
            }

            // 2. Body Split: Spatial Viewport (Left) + Preset Selector (Right)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Left: Spatial Arrangement Viewport
                SpatialArrangementViewport {
                    themeColors: window.themeColors
                    fontSans: window.fontSans
                    fontMono: window.fontMono
                    currentMode: window.currentMode
                    previewMode: window.previewMode
                    extendPosition: window.extendPosition
                    extMonitorName: window.extMonitorName
                    extMonitorRes: window.extMonitorRes
                    extMonitorRefresh: window.extMonitorRefresh
                    laptopName: window.laptopName
                    laptopRes: window.laptopRes
                    laptopRefresh: window.laptopRefresh
                }

                // Hairline vertical divider
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.35)
                }

                // Right: Preset Selector
                PresetSelector {
                    themeColors: window.themeColors
                    fontSans: window.fontSans
                    fontMono: window.fontMono
                    modesList: window.modesList
                    currentMode: window.currentMode
                    selectedIndex: window.selectedIndex
                    applyingMode: window.applyingMode
                    extendPosition: window.extendPosition
                    extMonitorName: window.extMonitorName

                    onModeSelected: (arg, index) => {
                        window.selectedIndex = index;
                        window.selectMode(arg);
                    }
                    onModeHovered: (modeId, index) => {
                        window.selectedIndex = index;
                        window.previewMode = modeId;
                    }
                    onCycleExtendPositionRequested: {
                        window.cycleExtendPosition();
                    }
                }
            }

            // 3. Footer Bar
            FooterBar {
                themeColors: window.themeColors
                fontSans: window.fontSans
                fontMono: window.fontMono
            }
        }
    }
}
