import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

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

    // Uniform scalar helper for layout geometry
    function s(val) {
        return Math.round(val);
    }

    // Resolution parsing helpers hoisted from spatial bounds footer
    function parseResWidth(resStr) {
        let parts = (resStr || "").split("×");
        return parts.length > 0 ? parseInt(parts[0].trim()) || 1920 : 1920;
    }

    function parseResHeight(resStr) {
        let parts = (resStr || "").split("×");
        return parts.length > 1 ? parseInt(parts[1].trim()) || 1080 : 1080;
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

    readonly property string fontMono: "CaskaydiaCove Nerd Font, CaskaydiaCove NF, monospace"
    readonly property string fontSans: "CaskaydiaCove Nerd Font, CaskaydiaCove NF, sans-serif"

    onPreviewModeChanged: {
        if (window.previewMode === "mirror" && beamCanvas) beamCanvas.requestPaint();
    }

    function getModeDesc(item) {
        if (item.modeId === "extend") {
            if (window.extendPosition === "right") return "Laptop on left · External on right";
            if (window.extendPosition === "top") return "External on top · Laptop below";
            return "External on left · Laptop on right";
        }
        return item.desc;
    }

    readonly property var modesList: [
        {
            modeId: "extend",
            arg: "--extend",
            key: "3",
            title: "Extend Desktop",
            desc: "External on left · Laptop on right"
        },
        {
            modeId: "mirror",
            arg: "--mirror",
            key: "2",
            title: "Mirror Display",
            desc: "Duplicate laptop screen onto external display"
        },
        {
            modeId: "laptop_only",
            arg: "--laptop-only",
            key: "1",
            title: "Laptop Screen Only",
            desc: "Internal display only · external powered off"
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
                        if (window.previewMode === "mirror" && beamCanvas) beamCanvas.requestPaint();
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
        implicitWidth: window.s(740)
        implicitHeight: window.s(330)
        width: implicitWidth
        height: implicitHeight
        radius: window.s(12)
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
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(40)
                    color: "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: window.s(18)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Display Arrangement"
                        font.family: window.fontSans
                        font.pixelSize: window.s(13)
                        font.weight: Font.DemiBold
                        color: window.themeColors.text || "#e6e3d5"
                    }

                    RowLayout {
                        anchors.right: parent.right
                        anchors.rightMargin: window.s(18)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: window.s(6)

                        // Error Alert Banner (visible on error)
                        Rectangle {
                            visible: window.errorMessage !== ""
                            implicitHeight: window.s(20)
                            implicitWidth: errPillLayout.implicitWidth + window.s(16)
                            radius: window.s(10)
                            color: Qt.alpha(window.themeColors.peach || "#f38ba8", 0.15)
                            border.width: 1
                            border.color: Qt.alpha(window.themeColors.peach || "#f38ba8", 0.45)

                            RowLayout {
                                id: errPillLayout
                                anchors.centerIn: parent
                                spacing: window.s(4)

                                Text {
                                    text: "⚠ " + window.errorMessage
                                    font.family: window.fontSans
                                    font.pixelSize: window.s(9)
                                    font.weight: Font.Medium
                                    color: window.themeColors.peach || "#f38ba8"
                                }
                            }
                        }

                        // Ambient subtle LED glow ring & core (visible when no error)
                        Item {
                            visible: window.errorMessage === ""
                            width: window.s(8)
                            height: window.s(8)

                            Rectangle {
                                anchors.centerIn: parent
                                width: window.s(8)
                                height: window.s(8)
                                radius: window.s(4)
                                color: window.extMonitorName !== ""
                                    ? Qt.alpha(window.themeColors.green || "#c9c8a5", 0.25)
                                    : "transparent"
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: window.s(5)
                                height: window.s(5)
                                radius: window.s(2.5)
                                color: window.extMonitorName !== ""
                                    ? (window.themeColors.green || "#c9c8a5")
                                    : (window.themeColors.subtext1 || "#939182")
                            }
                        }

                        Text {
                            visible: window.errorMessage === ""
                            text: window.extMonitorName !== ""
                                ? (window.extMonitorDesc + " • " + window.extMonitorRefresh)
                                : (window.laptopDesc + " (" + window.laptopRefresh + " Only)")
                            font.family: window.fontMono
                            font.pixelSize: window.s(10)
                            color: window.themeColors.subtext0 || "#c9c7b6"
                            elide: Text.ElideRight
                            Layout.maximumWidth: window.s(260)
                        }
                    }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.35)
                }
            }

            // 2. Body Split: Spatial Canvas (Left) + Presets List (Right)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ─── LEFT: SPATIAL ARRANGEMENT VIEWPORT ───
                Rectangle {
                    Layout.preferredWidth: window.s(390)
                    Layout.fillHeight: true
                    color: Qt.alpha(window.themeColors.crust || "#14140c", 0.5)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: window.s(16)
                        spacing: window.s(8)

                        // Mode Context Label
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: {
                                    if (window.previewMode === "extend") {
                                        return "Dual display — extended (" + (window.extendPosition === "left" ? "left" : (window.extendPosition === "right" ? "right" : "top")) + ")";
                                    }
                                    if (window.previewMode === "mirror") return "Presentation — mirrored display";
                                    if (window.previewMode === "laptop_only") return "Internal display only";
                                    return "External display only";
                                }
                                font.family: window.fontSans
                                font.pixelSize: window.s(9.5)
                                font.weight: Font.Normal
                                color: window.themeColors.subtext0 || "#c9c7b6"
                                opacity: (window.previewMode !== window.currentMode) ? 1.0 : 0.75
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            Item { Layout.fillWidth: true }
                            // "Previewing" badge — appears only when hovering a different mode
                            Text {
                                visible: (window.previewMode !== window.currentMode)
                                text: "preview"
                                font.family: window.fontMono
                                font.pixelSize: window.s(8)
                                color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.65)
                                opacity: visible ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        // Spatial Geometry Canvas Container
                        Item {
                            id: canvasContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Elevated Surface with Soft Drop Shadow (Stroke-free)
                            Rectangle {
                                id: canvasBg
                                anchors.fill: parent
                                radius: window.s(8)
                                color: Qt.alpha(window.themeColors.base || "#0f0f07", 0.8)
                                border.width: 0
                                border.color: "transparent"

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor: "#000000"
                                    shadowOpacity: 0.35
                                    shadowBlur: 0.7
                                    shadowVerticalOffset: window.s(2.5)
                                    shadowHorizontalOffset: 0
                                }
                            }

                            // Spatial Canvas Contents (Clipped)
                            Item {
                                id: canvasSurface
                                anchors.fill: parent
                                clip: true

                            // Table / Desk Baseline
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: window.s(22)
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: window.s(16)
                                anchors.rightMargin: window.s(16)
                                height: 1
                                color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.45)
                            }

                            // Subtle Elegant Projection Beam for Mirror Mode
                            Canvas {
                                id: beamCanvas
                                anchors.fill: parent
                                z: 0
                                visible: opacity > 0.01
                                opacity: (window.previewMode === "mirror") ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                property real beamSpread: (window.previewMode === "mirror") ? 1.0 : 0.0
                                Behavior on beamSpread { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                onBeamSpreadChanged: requestPaint()
                                onAvailableChanged: if (available && window.previewMode === "mirror") requestPaint()
                                Component.onCompleted: if (available && window.previewMode === "mirror") requestPaint()

                                onPaint: {
                                    let ctx = getContext("2d");
                                    if (!ctx) return;
                                    ctx.clearRect(0, 0, width, height);

                                    if (window.previewMode !== "mirror" && beamSpread <= 0.005) return;

                                    // Projector lens aperture center
                                    let lx = extSlot.x + projectorContainer.x + projectorContainer.width - window.s(8);
                                    let ly = extSlot.y + projectorContainer.y + window.s(25);

                                    // Laptop screen target boundary
                                    let tx = laptopContainer.x + (laptopContainer.width - laptopScreen.width) / 2;
                                    let lcy = laptopContainer.y + laptopScreen.y + (laptopScreen.height / 2);
                                    let fullHalfH = laptopScreen.height / 2;

                                    // Smooth spreading & extending animation towards laptop screen
                                    let currentTx = lx + (tx - lx) * (0.35 + 0.65 * beamSpread);
                                    let currentHalfH = fullHalfH * Math.max(0.08, beamSpread);
                                    let tyTop = lcy - currentHalfH;
                                    let tyBottom = lcy + currentHalfH;

                                    let mColor = Qt.color(window.themeColors.mauve || "#cacb77");
                                    let mr = mColor.r;
                                    let mg = mColor.g;
                                    let mb = mColor.b;

                                    // Soft, elegant light cone gradient (subtle 15% -> 4% -> 0%)
                                    let grad = ctx.createLinearGradient(lx, ly, currentTx, ly);
                                    grad.addColorStop(0.0, Qt.rgba(mr, mg, mb, 0.15));
                                    grad.addColorStop(0.55, Qt.rgba(mr, mg, mb, 0.04));
                                    grad.addColorStop(1.0, Qt.rgba(mr, mg, mb, 0.0));

                                    ctx.fillStyle = grad;
                                    ctx.beginPath();
                                    ctx.moveTo(lx, ly - window.s(4));
                                    ctx.lineTo(currentTx, tyTop);
                                    ctx.lineTo(currentTx, tyBottom);
                                    ctx.lineTo(lx, ly + window.s(4));
                                    ctx.closePath();
                                    ctx.fill();

                                    // Hairline center projection ray
                                    let lineGrad = ctx.createLinearGradient(lx, ly, currentTx, ly);
                                    lineGrad.addColorStop(0.0, Qt.rgba(mr, mg, mb, 0.20));
                                    lineGrad.addColorStop(0.75, Qt.rgba(mr, mg, mb, 0.02));
                                    lineGrad.addColorStop(1.0, Qt.rgba(mr, mg, mb, 0.0));
                                    ctx.strokeStyle = lineGrad;
                                    ctx.lineWidth = 1;
                                    ctx.beginPath();
                                    ctx.moveTo(lx, ly);
                                    ctx.lineTo(currentTx, ly);
                                    ctx.stroke();
                                }
                            }

                            // ─── 1. EXTERNAL DISPLAY SLOT (Left: Monitor Stand OR Projector) ───
                            Item {
                                id: extSlot
                                z: 1
                                width: window.s(164)
                                height: window.s(104)
                                x: {
                                    if (window.previewMode === "extend") {
                                        if (window.extendPosition === "right") {
                                            return canvasSurface.width - width - window.s(16);
                                        } else if (window.extendPosition === "top") {
                                            return Math.round((canvasSurface.width - width) / 2);
                                        } else {
                                            return window.s(16);
                                        }
                                    }
                                    return (window.previewMode === "projector_only") ? window.s(22) : window.s(16);
                                }
                                y: {
                                    if (window.previewMode === "extend" && window.extendPosition === "top") {
                                        return window.s(6);
                                    }
                                    return parent.height - window.s(22) - height;
                                }

                                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                onXChanged: if (window.previewMode === "mirror" && beamCanvas) beamCanvas.requestPaint()
                                onYChanged: if (window.previewMode === "mirror" && beamCanvas) beamCanvas.requestPaint()

                                // (A) Desktop Monitor Representation (in Extend / Laptop Only / External Only)
                                Column {
                                    id: monitorContainer
                                    width: window.s(158)
                                    height: window.s(102.5)
                                    transformOrigin: Item.Center
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: monitorContainer.isStandby ? (parent.height - height + window.s(4)) : (parent.height - height)
                                    spacing: 0
                                    visible: opacity > 0.01
                                    opacity: (window.previewMode === "mirror") ? 0.0 : (isStandby ? 0.25 : 1.0)
                                    scale: {
                                        if (window.previewMode === "mirror") return 0.92;
                                        if (isStandby) return 0.97;
                                        if (window.previewMode === "extend" && window.extendPosition === "top") return 0.82;
                                        return 1.0;
                                    }

                                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                    readonly property bool isStandby: (window.previewMode === "laptop_only")

                                    // 1. Monitor Screen Panel
                                    Rectangle {
                                        id: monitorScreen
                                        width: window.s(158)
                                        height: window.s(90)
                                        radius: window.s(5)

                                        color: monitorContainer.isStandby
                                            ? Qt.alpha(window.themeColors.crust || "#14140c", 0.8)
                                            : Qt.alpha(window.themeColors.surface0 || "#202018", 0.95)

                                        border.width: 1
                                        border.color: monitorContainer.isStandby
                                            ? Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.4)
                                            : ((window.previewMode === "extend" || window.previewMode === "projector_only")
                                                ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.45)
                                                : Qt.alpha(window.themeColors.surface2 || "#36352c", 0.6))

                                        Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                        // Glass panel top specular reflection
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 1
                                            height: 1
                                            radius: window.s(4)
                                            color: monitorContainer.isStandby
                                                ? "transparent"
                                                : Qt.alpha(window.themeColors.text || "#e6e3d5", 0.08)
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: window.s(8)
                                            spacing: window.s(1)

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: window.extMonitorName !== "" ? window.extMonitorName : "External"
                                                    font.family: window.fontMono
                                                    font.pixelSize: window.s(9)
                                                    font.weight: Font.Bold
                                                    color: monitorContainer.isStandby
                                                        ? Qt.alpha(window.themeColors.subtext1 || "#939182", 0.4)
                                                        : (window.themeColors.text || "#e6e3d5")
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: {
                                                        if (monitorContainer.isStandby) return "off";
                                                        if (window.previewMode === "projector_only") return "primary";
                                                        if (window.previewMode === "extend") {
                                                            if (window.extendPosition === "right") return "primary →";
                                                            if (window.extendPosition === "top") return "↑ primary";
                                                            return "← primary";
                                                        }
                                                        return "external";
                                                    }
                                                    font.family: window.fontSans
                                                    font.pixelSize: window.s(8)
                                                    color: monitorContainer.isStandby
                                                        ? Qt.alpha(window.themeColors.subtext1 || "#939182", 0.4)
                                                        : (window.themeColors.mauve || "#cacb77")
                                                }
                                            }

                                            Item { Layout.fillHeight: true }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: monitorContainer.isStandby ? "Standby" : (window.extMonitorRefresh !== "" ? window.extMonitorRefresh : "Active")
                                                font.family: window.fontMono
                                                font.pixelSize: monitorContainer.isStandby ? window.s(10) : window.s(14)
                                                font.weight: Font.Bold
                                                color: monitorContainer.isStandby
                                                    ? Qt.alpha(window.themeColors.subtext1 || "#939182", 0.6)
                                                    : (window.themeColors.mauve || "#cacb77")
                                            }

                                            Item { Layout.fillHeight: true }

                                            Text {
                                                text: window.extMonitorRes + (window.extMonitorRefresh !== "" ? (" (" + window.extMonitorRefresh + ")") : "")
                                                font.family: window.fontMono
                                                font.pixelSize: window.s(8.5)
                                                font.letterSpacing: 0.2
                                                color: monitorContainer.isStandby
                                                    ? Qt.alpha(window.themeColors.subtext1 || "#939182", 0.6)
                                                    : Qt.alpha(window.themeColors.subtext1 || "#939182", 0.85)
                                            }
                                        }
                                    }

                                    // 2. Monitor Stand Neck (Leher Tiang)
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: window.s(12)
                                        height: window.s(9)
                                        color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.95)
                                        border.width: 1
                                        border.color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.6)
                                    }

                                    // 3. Monitor Stand Base (Kaki Penyangga)
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: window.s(54)
                                        height: window.s(3.5)
                                        radius: window.s(1.75)
                                        color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.95)
                                        border.width: 1
                                        border.color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.8)
                                    }
                                }

                                // (B) Minimalist Projector Hardware Representation (in Mirror Mode)
                                Item {
                                    id: projectorContainer
                                    width: window.s(122)
                                    height: window.s(56)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: (window.previewMode === "mirror") ? (parent.height - height) : (parent.height - height + window.s(6))
                                    visible: opacity > 0.01
                                    opacity: (window.previewMode === "mirror") ? 1.0 : 0.0
                                    scale: (window.previewMode === "mirror") ? 1.0 : 0.92

                                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                    onYChanged: if (window.previewMode === "mirror" && beamCanvas) beamCanvas.requestPaint()

                                    Column {
                                        anchors.fill: parent
                                        spacing: 0

                                        // Projector Body
                                        Rectangle {
                                            id: projectorBody
                                            width: parent.width
                                            height: window.s(50)
                                            radius: window.s(6)
                                            color: Qt.alpha(window.themeColors.surface0 || "#202018", 0.95)
                                            border.width: 1
                                            border.color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.45)

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: window.s(8)
                                                spacing: window.s(6)

                                                // Left: Vents & Status Info
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: window.s(2)

                                                    RowLayout {
                                                        spacing: window.s(4)

                                                        Rectangle {
                                                            width: window.s(5)
                                                            height: window.s(5)
                                                            radius: window.s(2.5)
                                                            color: window.themeColors.green || "#c9c8a5"
                                                        }

                                                        Text {
                                                            text: "PROJECTOR"
                                                            font.family: window.fontMono
                                                            font.pixelSize: window.s(9)
                                                            font.weight: Font.Bold
                                                            color: window.themeColors.mauve || "#cacb77"
                                                        }
                                                    }

                                                    Text {
                                                        text: window.extMonitorName !== "" ? window.extMonitorName : "External"
                                                        font.family: window.fontMono
                                                        font.pixelSize: window.s(8)
                                                        color: window.themeColors.text || "#e6e3d5"
                                                    }

                                                    Text {
                                                        text: "Mirror Duplicate"
                                                        font.family: window.fontSans
                                                        font.pixelSize: window.s(7.5)
                                                        color: window.themeColors.subtext1 || "#939182"
                                                    }
                                                }

                                                // Right: Optical Lens Aperture
                                                Rectangle {
                                                    width: window.s(24)
                                                    height: window.s(24)
                                                    radius: window.s(12)
                                                    color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.9)
                                                    border.width: 1.5
                                                    border.color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.5)

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: window.s(12)
                                                        height: window.s(12)
                                                        radius: window.s(6)
                                                        color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.25)
                                                        border.width: 1
                                                        border.color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.45)
                                                    }
                                                }
                                            }
                                        }

                                        // Projector Feet Pads
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: window.s(80)

                                            Rectangle {
                                                width: window.s(10)
                                                height: window.s(3)
                                                radius: window.s(1)
                                                color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.9)
                                            }
                                            Rectangle {
                                                width: window.s(10)
                                                height: window.s(3)
                                                radius: window.s(1)
                                                color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.9)
                                            }
                                        }
                                    }
                                }
                            }

                            // ─── 2. LAPTOP DISPLAY SLOT (Right: Screen Lid + Keyboard Chassis & Touchpad Notch) ───
                            Column {
                                id: laptopContainer
                                width: window.s(148)
                                height: window.s(84.5)
                                transformOrigin: Item.Center
                                spacing: window.s(1)

                                readonly property bool isStandby: (window.previewMode === "projector_only")

                                x: {
                                    if (window.previewMode === "extend") {
                                        if (window.extendPosition === "right") {
                                            return window.s(16);
                                        } else if (window.extendPosition === "top") {
                                            return Math.round((canvasSurface.width - width) / 2);
                                        } else {
                                            return canvasSurface.width - width - window.s(16);
                                        }
                                    }
                                    return (window.previewMode === "laptop_only")
                                        ? (canvasSurface.width - width - window.s(22))
                                        : (canvasSurface.width - width - window.s(16));
                                }

                                y: {
                                    let baseY = canvasSurface.height - window.s(22) - height;
                                    if (window.previewMode === "extend" && window.extendPosition === "top") {
                                        return baseY + window.s(2);
                                    }
                                    return baseY + (isStandby ? window.s(4) : 0);
                                }

                                opacity: isStandby ? 0.25 : 1.0
                                scale: {
                                    if (isStandby) return 0.97;
                                    if (window.previewMode === "extend" && window.extendPosition === "top") return 0.84;
                                    return 1.0;
                                }

                                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                onXChanged: if (window.previewMode === "mirror" && beamCanvas) beamCanvas.requestPaint()
                                onYChanged: if (window.previewMode === "mirror" && beamCanvas) beamCanvas.requestPaint()

                                // 1. Laptop Screen Lid
                                Rectangle {
                                    id: laptopScreen
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: window.s(138)
                                    height: window.s(78)
                                    radius: window.s(4)

                                    color: laptopContainer.isStandby
                                        ? Qt.alpha(window.themeColors.crust || "#14140c", 0.8)
                                        : Qt.alpha(window.themeColors.surface0 || "#202018", 0.95)

                                    border.width: 1
                                    border.color: laptopContainer.isStandby
                                        ? Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.4)
                                        : ((window.previewMode === "laptop_only" || window.previewMode === "mirror")
                                            ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.45)
                                            : Qt.alpha(window.themeColors.surface2 || "#36352c", 0.6))

                                    Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                    // Glass panel top specular reflection
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                        height: 1
                                        radius: window.s(3)
                                        color: laptopContainer.isStandby
                                            ? "transparent"
                                            : Qt.alpha(window.themeColors.text || "#e6e3d5", 0.08)
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: window.s(7)
                                        spacing: window.s(1)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: window.laptopName !== "" ? window.laptopName : "Internal"
                                                font.family: window.fontMono
                                                font.pixelSize: window.s(9)
                                                font.weight: Font.Bold
                                                color: laptopContainer.isStandby
                                                    ? Qt.alpha(window.themeColors.subtext1 || "#939182", 0.4)
                                                    : (window.themeColors.text || "#e6e3d5")
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: {
                                                    if (laptopContainer.isStandby) return "off";
                                                    if (window.previewMode === "extend") {
                                                        if (window.extendPosition === "right") return "← extended";
                                                        if (window.extendPosition === "top") return "↓ extended";
                                                        return "→ extended";
                                                    }
                                                    return "primary";
                                                }
                                                font.family: window.fontSans
                                                font.pixelSize: window.s(8)
                                                color: laptopContainer.isStandby
                                                    ? Qt.alpha(window.themeColors.subtext1 || "#939182", 0.4)
                                                    : ((window.previewMode === "mirror") ? (window.themeColors.mauve || "#cacb77") : (window.themeColors.subtext0 || "#c9c7b6"))
                                            }
                                        }

                                        Item { Layout.fillHeight: true }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: laptopContainer.isStandby ? "Standby" : (window.previewMode === "mirror" ? ((window.laptopRefresh || "60Hz") + " (Source)") : (window.laptopRefresh || "60Hz"))
                                            font.family: window.fontMono
                                            font.pixelSize: laptopContainer.isStandby ? window.s(10) : window.s(13)
                                            font.weight: Font.Bold
                                            color: laptopContainer.isStandby
                                                ? Qt.alpha(window.themeColors.subtext1 || "#939182", 0.6)
                                                : (window.previewMode === "mirror" ? (window.themeColors.mauve || "#cacb77") : (window.themeColors.text || "#e6e3d5"))
                                        }

                                        Item { Layout.fillHeight: true }

                                        Text {
                                            text: window.laptopRes + (window.laptopRefresh !== "" ? (" (" + window.laptopRefresh + ")") : "")
                                            font.family: window.fontMono
                                            font.pixelSize: window.s(8.5)
                                            font.letterSpacing: 0.2
                                            color: laptopContainer.isStandby
                                                ? Qt.alpha(window.themeColors.subtext1 || "#939182", 0.6)
                                                : Qt.alpha(window.themeColors.subtext1 || "#939182", 0.85)
                                        }
                                    }
                                }

                                // 2. Laptop Keyboard Chassis & Touchpad Notch
                                Rectangle {
                                    id: laptopChassis
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: window.s(150)
                                    height: window.s(6)
                                    radius: window.s(2)
                                    color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.95)
                                    border.width: 1
                                    border.color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.7)

                                    // Touchpad Notch
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        width: window.s(24)
                                        height: window.s(2)
                                        radius: window.s(1)
                                        color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.9)
                                    }
                                }
                            }
                        }
                    }

                        // Spatial Bounds Footer
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: {
                                    if (window.previewMode === "extend") {
                                        let w1 = window.parseResWidth(window.extMonitorRes);
                                        let w2 = window.parseResWidth(window.laptopRes);
                                        let h1 = window.parseResHeight(window.extMonitorRes);
                                        let h2 = window.parseResHeight(window.laptopRes);
                                        if (window.extendPosition === "top") {
                                            let maxW = Math.max(w1, w2);
                                            let totalH = h1 + h2;
                                            return "Boundary: " + maxW + " × " + totalH + " px stacked canvas";
                                        } else {
                                            let maxH = Math.max(h1, h2);
                                            return "Boundary: " + (w1 + w2) + " × " + maxH + " px virtual canvas";
                                        }
                                    } else if (window.previewMode === "mirror") {
                                        return "Presentation: duplicate display output";
                                    } else {
                                        let res = (window.previewMode === "projector_only") ? window.extMonitorRes : window.laptopRes;
                                        return "Boundary: " + (res || "1920 × 1080") + " px single output";
                                    }
                                }
                                font.family: window.fontMono
                                font.pixelSize: window.s(8)
                                color: Qt.alpha(window.themeColors.subtext1 || "#939182", 0.8)
                            }
                        }
                    }
                }

                // Hairline vertical divider
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.35)
                }

                // ─── RIGHT: PRESET SELECTOR (Quiet, High Contrast, Tactile) ───
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    Item {
                        id: presetArea
                        anchors.fill: parent
                        anchors.margins: window.s(10)

                        // Smooth Sliding Selection Indicator Pill
                        Rectangle {
                            id: focusIndicator
                            z: 0
                            x: 0
                            width: presetArea.width
                            readonly property real rowHeight: (presetArea.height - (window.modesList.length - 1) * window.s(3)) / window.modesList.length
                            height: rowHeight
                            y: window.selectedIndex * (rowHeight + window.s(3))
                            radius: window.s(6)
                            color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.75)
                            border.width: 1
                            border.color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.55)

                            Behavior on y {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Inset glass specular edge
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 1
                                height: 1
                                radius: window.s(5)
                                color: Qt.alpha(window.themeColors.text || "#e6e3d5", 0.08)
                            }
                        }

                        ColumnLayout {
                            id: presetColumn
                            z: 1
                            anchors.fill: parent
                            spacing: window.s(3)

                            Repeater {
                                model: window.modesList

                                delegate: Item {
                                    id: presetItem
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    readonly property bool isCurrent: (window.currentMode === modelData.modeId)
                                    readonly property bool isFocused: (window.selectedIndex === index)
                                    readonly property bool isHovered: itemMa.containsMouse
                                    readonly property bool isAvailable: (modelData.modeId === "laptop_only" || window.extMonitorName !== "")

                                    opacity: isAvailable ? 1.0 : 0.42
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    scale: itemMa.pressed ? 0.985 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                    // Subtle resting background for active mode when NOT currently focused by sliding indicator
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: window.s(6)
                                        visible: presetItem.isCurrent && !presetItem.isFocused
                                        color: Qt.alpha(window.themeColors.surface0 || "#202018", 0.5)
                                    }

                                    // Active accent tick on left
                                    Rectangle {
                                        visible: presetItem.isCurrent
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.margins: window.s(5)
                                        width: window.s(2.5)
                                        radius: window.s(1.25)
                                        color: window.themeColors.mauve || "#cacb77"
                                    }

                                    RowLayout {
                                        z: 1
                                        anchors.fill: parent
                                        anchors.leftMargin: window.s(12)
                                        anchors.rightMargin: window.s(12)
                                        spacing: window.s(10)

                                        // Keycap with machined bezel
                                        Rectangle {
                                            width: window.s(20)
                                            height: window.s(20)
                                            radius: window.s(4)
                                            color: presetItem.isCurrent
                                                ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.18)
                                                : Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.85)
                                            border.width: 1
                                            border.color: presetItem.isCurrent
                                                ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.45)
                                                : Qt.alpha(window.themeColors.surface2 || "#36352c", 0.6)

                                            // Inner top highlight for physical keycap depth
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.margins: 1
                                                height: 1
                                                radius: window.s(3)
                                                color: Qt.alpha(window.themeColors.text || "#e6e3d5", 0.1)
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.key
                                                font.family: window.fontMono
                                                font.pixelSize: window.s(10)
                                                font.weight: Font.Bold
                                                color: presetItem.isCurrent
                                                    ? (window.themeColors.mauve || "#cacb77")
                                                    : (window.themeColors.text || "#e6e3d5")
                                            }
                                        }

                                        // Text Information
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            RowLayout {
                                                spacing: window.s(5)

                                                // Pulsing active dot when applying mode
                                                Rectangle {
                                                    visible: window.applyingMode && presetItem.isFocused
                                                    width: window.s(6)
                                                    height: window.s(6)
                                                    radius: window.s(3)
                                                    color: window.themeColors.mauve || "#cacb77"

                                                    SequentialAnimation on opacity {
                                                        running: window.applyingMode && presetItem.isFocused
                                                        loops: Animation.Infinite
                                                        NumberAnimation { from: 0.2; to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
                                                        NumberAnimation { from: 1.0; to: 0.2; duration: 350; easing.type: Easing.InOutQuad }
                                                    }
                                                }

                                                Text {
                                                    text: (window.applyingMode && presetItem.isFocused)
                                                        ? "Applying…"
                                                        : modelData.title
                                                    font.family: window.fontSans
                                                    font.pixelSize: window.s(12)
                                                    font.weight: Font.DemiBold
                                                    color: (window.applyingMode && presetItem.isFocused)
                                                        ? (window.themeColors.mauve || "#cacb77")
                                                        : ((presetItem.isHovered || presetItem.isFocused || presetItem.isCurrent)
                                                            ? (window.themeColors.text || "#e6e3d5")
                                                            : (window.themeColors.subtext0 || "#c9c7b6"))
                                                }
                                            }

                                            Text {
                                                text: !presetItem.isAvailable ? "External display disconnected" : window.getModeDesc(modelData)
                                                font.family: window.fontSans
                                                font.pixelSize: window.s(10)
                                                color: !presetItem.isAvailable
                                                    ? Qt.alpha(window.themeColors.peach || "#f38ba8", 0.7)
                                                    : (window.themeColors.subtext1 || "#939182")
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        // Interactive Position Swap Chip (for Extend Desktop mode)
                                        Rectangle {
                                            id: posChip
                                            visible: modelData.modeId === "extend" && presetItem.isAvailable
                                            implicitHeight: window.s(18)
                                            implicitWidth: posChipLayout.implicitWidth + window.s(12)
                                            radius: window.s(4)
                                            scale: posChipMa.pressed ? 0.94 : (posChipMa.containsMouse ? 1.03 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                            color: posChipMa.pressed
                                                ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.25)
                                                : (presetItem.isFocused
                                                    ? Qt.alpha(window.themeColors.surface2 || "#36352c", 0.95)
                                                    : Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.75))
                                            border.width: 1
                                            border.color: presetItem.isFocused
                                                ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.5)
                                                : Qt.alpha(window.themeColors.surface2 || "#36352c", 0.5)

                                            RowLayout {
                                                id: posChipLayout
                                                anchors.centerIn: parent
                                                spacing: window.s(4)

                                                Text {
                                                    text: "⇄"
                                                    font.family: window.fontMono
                                                    font.pixelSize: window.s(9)
                                                    color: window.themeColors.mauve || "#cacb77"
                                                }
                                                Text {
                                                    text: window.extendPosition.toUpperCase()
                                                    font.family: window.fontMono
                                                    font.pixelSize: window.s(8)
                                                    font.weight: Font.Bold
                                                    color: window.themeColors.text || "#e6e3d5"
                                                }
                                            }

                                            MouseArea {
                                                id: posChipMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: (mouse) => {
                                                    mouse.accepted = true;
                                                    window.cycleExtendPosition();
                                                }
                                            }
                                        }

                                        // Clean subtle Active Pill with indicator dot
                                        Rectangle {
                                            visible: presetItem.isCurrent
                                            implicitHeight: window.s(18)
                                            implicitWidth: pillLayout.implicitWidth + window.s(14)
                                            radius: window.s(9)
                                            color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.12)
                                            border.width: 1
                                            border.color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.3)

                                            RowLayout {
                                                id: pillLayout
                                                anchors.centerIn: parent
                                                spacing: window.s(4)

                                                Rectangle {
                                                    width: window.s(4)
                                                    height: window.s(4)
                                                    radius: window.s(2)
                                                    color: window.themeColors.mauve || "#cacb77"
                                                }

                                                Text {
                                                    text: "Active"
                                                    font.family: window.fontSans
                                                    font.pixelSize: window.s(9)
                                                    font.weight: Font.Medium
                                                    color: window.themeColors.mauve || "#cacb77"
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: itemMa
                                        z: 0
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: presetItem.isAvailable ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onEntered: {
                                            window.selectedIndex = index;
                                            window.previewMode = modelData.modeId;
                                        }
                                        onClicked: {
                                            if (!presetItem.isAvailable) {
                                                window.errorMessage = "External display disconnected";
                                                errorTimer.restart();
                                                return;
                                            }
                                            window.selectMode(modelData.arg);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. Footer Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(28)
                color: "transparent"

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.35)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.s(16)
                    anchors.rightMargin: window.s(16)
                    spacing: window.s(8)

                    RowLayout {
                        spacing: window.s(4)
                        Rectangle {
                            width: window.s(18)
                            height: window.s(14)
                            radius: window.s(3)
                            color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.75)
                            border.width: 1
                            border.color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.7)
                            Text {
                                anchors.centerIn: parent
                                text: "↑↓"
                                font.family: window.fontMono
                                font.pixelSize: window.s(7.5)
                                color: window.themeColors.subtext0 || "#c9c7b6"
                            }
                        }
                        Text {
                            text: "Navigate"
                            font.family: window.fontSans
                            font.pixelSize: window.s(8.5)
                            color: window.themeColors.subtext1 || "#939182"
                        }
                    }

                    Text {
                        text: "•"
                        font.pixelSize: window.s(8)
                        color: Qt.alpha(window.themeColors.subtext1 || "#939182", 0.4)
                    }

                    RowLayout {
                        spacing: window.s(4)
                        Rectangle {
                            width: window.s(22)
                            height: window.s(14)
                            radius: window.s(3)
                            color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.75)
                            border.width: 1
                            border.color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.7)
                            Text {
                                anchors.centerIn: parent
                                text: "1-4"
                                font.family: window.fontMono
                                font.pixelSize: window.s(7.5)
                                color: window.themeColors.subtext0 || "#c9c7b6"
                            }
                        }
                        Text {
                            text: "Quick"
                            font.family: window.fontSans
                            font.pixelSize: window.s(8.5)
                            color: window.themeColors.subtext1 || "#939182"
                        }
                    }

                    Text {
                        text: "•"
                        font.pixelSize: window.s(8)
                        color: Qt.alpha(window.themeColors.subtext1 || "#939182", 0.4)
                    }

                    RowLayout {
                        spacing: window.s(4)
                        Rectangle {
                            width: window.s(38)
                            height: window.s(14)
                            radius: window.s(3)
                            color: (window.previewMode === "extend")
                                ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.18)
                                : Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.75)
                            border.width: 1
                            border.color: (window.previewMode === "extend")
                                ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.45)
                                : Qt.alpha(window.themeColors.surface2 || "#36352c", 0.7)
                            Text {
                                anchors.centerIn: parent
                                text: "S / Tab"
                                font.family: window.fontMono
                                font.pixelSize: window.s(7.5)
                                font.weight: (window.previewMode === "extend") ? Font.Bold : Font.Normal
                                color: (window.previewMode === "extend")
                                    ? (window.themeColors.mauve || "#cacb77")
                                    : (window.themeColors.subtext0 || "#c9c7b6")
                            }
                        }
                        Text {
                            text: "Swap Pos" + ((window.previewMode === "extend") ? (" (" + (window.extendPosition.charAt(0).toUpperCase() + window.extendPosition.slice(1)) + ")") : "")
                            font.family: window.fontSans
                            font.pixelSize: window.s(8.5)
                            color: (window.previewMode === "extend")
                                ? (window.themeColors.text || "#e6e3d5")
                                : (window.themeColors.subtext1 || "#939182")
                        }
                    }

                    Text {
                        text: "•"
                        font.pixelSize: window.s(8)
                        color: Qt.alpha(window.themeColors.subtext1 || "#939182", 0.4)
                    }

                    RowLayout {
                        spacing: window.s(4)
                        Rectangle {
                            width: window.s(16)
                            height: window.s(14)
                            radius: window.s(3)
                            color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.75)
                            border.width: 1
                            border.color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.7)
                            Text {
                                anchors.centerIn: parent
                                text: "↵"
                                font.family: window.fontMono
                                font.pixelSize: window.s(7.5)
                                color: window.themeColors.subtext0 || "#c9c7b6"
                            }
                        }
                        Text {
                            text: "Confirm"
                            font.family: window.fontSans
                            font.pixelSize: window.s(8.5)
                            color: window.themeColors.subtext1 || "#939182"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: window.s(4)
                        Rectangle {
                            width: window.s(24)
                            height: window.s(14)
                            radius: window.s(3)
                            color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.75)
                            border.width: 1
                            border.color: Qt.alpha(window.themeColors.surface2 || "#36352c", 0.7)
                            Text {
                                anchors.centerIn: parent
                                text: "esc"
                                font.family: window.fontMono
                                font.pixelSize: window.s(7.5)
                                color: window.themeColors.subtext1 || "#939182"
                            }
                        }
                        Text {
                            text: "Dismiss"
                            font.family: window.fontSans
                            font.pixelSize: window.s(8.5)
                            color: window.themeColors.subtext1 || "#939182"
                        }
                    }
                }
            }
        }
    }
}


