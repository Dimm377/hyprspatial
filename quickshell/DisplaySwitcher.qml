import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    function s(val) {
        return Math.round(val);
    }

    property string extMonitorName: ""
    property string extMonitorDesc: ""
    property string extMonitorRefresh: ""
    property string extMonitorRes: "1920×1080"
    property string laptopName: ""
    property string laptopDesc: "Internal Display"
    property string laptopRefresh: ""
    property string laptopRes: "1920×1080"
    property string extendPosition: "left"
    property string currentMode: "extend"
    property string previewMode: currentMode
    property int selectedIndex: 2
    property bool applyingMode: false
    property string errorMessage: ""

    // Typography: Human sans-serif for UI labels, monospace strictly for hardware/data
    readonly property string fontSans: "Google Sans, Adwaita Sans, Inter, Cantarell, Roboto, sans-serif"
    readonly property string fontMono: "CaskaydiaCove Nerd Font, CaskaydiaCove NF, monospace"

    readonly property var modesList: [
        {
            modeId: "laptop_only",
            arg: "--laptop-only",
            key: "1",
            title: "Laptop display only",
            desc: "Internal display active · external powered off"
        },
        {
            modeId: "mirror",
            arg: "--mirror",
            key: "2",
            title: "Mirror display",
            desc: "Duplicate laptop screen onto external display"
        },
        {
            modeId: "extend",
            arg: "--extend",
            key: "3",
            title: "Extend desktop",
            desc: "Dual displays · expand workspace"
        },
        {
            modeId: "projector_only",
            arg: "--projector-only",
            key: "4",
            title: "External display only",
            desc: "External display active · laptop screen powered off"
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
        "sapphire": "#74c7ec",
        "peach": "#f38ba8",
        "mauve": "#cacb77",
        "green": "#a6e3a1",
        "crust": "#14140c"
    })

    // Serpantinum dynamic color sync
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

    // Monitor topology detection
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
                            window.laptopRes = laptop.width + "×" + laptop.height;
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
                            window.extMonitorRes = ext.width + "×" + ext.height;
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
                window.errorMessage = errMsg ? errMsg : ("Failed to apply (code " + exitCode + ")");
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

        let scriptPath = StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/hypr/scripts/toggle-presentation.sh";
        if (arg === "--extend") {
            applyProc.command = [scriptPath, "--extend", window.extendPosition];
        } else {
            applyProc.command = [scriptPath, arg];
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
            NumberAnimation { target: mainCard; property: "opacity"; to: 0.0; duration: 80; easing.type: Easing.InCubic }
            NumberAnimation { target: mainCard; property: "scale"; to: 0.98; duration: 80; easing.type: Easing.InCubic }
            NumberAnimation { target: backdropDim; property: "opacity"; to: 0.0; duration: 90; easing.type: Easing.InCubic }
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

    // Direct keyboard shortcuts
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

    // Ambient backdrop
    Rectangle {
        id: backdropDim
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
            onClicked: window.closeWindow()
        }
    }

    // Executive HUD Card
    Rectangle {
        id: mainCard
        anchors.centerIn: parent
        implicitWidth: window.s(520)
        implicitHeight: window.s(328)
        width: implicitWidth
        height: implicitHeight
        radius: window.s(10)
        color: Qt.alpha(window.themeColors.base || "#0f0f07", 0.98)
        border.width: 1
        border.color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.55)
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
            } else if (event.key === Qt.Key_S || event.text === "s" || event.text === "S" || event.key === Qt.Key_Tab) {
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
            NumberAnimation { target: mainCard; property: "opacity"; from: 0.0; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: mainCard; property: "scale"; from: 0.98; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
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
                Layout.preferredHeight: window.s(44)
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.s(16)
                    anchors.rightMargin: window.s(16)
                    spacing: window.s(8)

                    Text {
                        text: "Displays"
                        font.family: window.fontSans
                        font.pixelSize: window.s(13)
                        font.weight: Font.DemiBold
                        color: window.themeColors.text || "#e6e3d5"
                    }

                    Item { Layout.fillWidth: true }

                    // Error Notification (if any)
                    RowLayout {
                        visible: window.errorMessage !== ""
                        spacing: window.s(5)

                        Rectangle {
                            width: window.s(6)
                            height: window.s(6)
                            radius: window.s(3)
                            color: window.themeColors.peach || "#f38ba8"
                        }

                        Text {
                            text: window.errorMessage
                            font.family: window.fontSans
                            font.pixelSize: window.s(10)
                            font.weight: Font.Medium
                            color: window.themeColors.peach || "#f38ba8"
                        }
                    }

                    // Connected Monitor Metadata
                    RowLayout {
                        visible: window.errorMessage === ""
                        spacing: window.s(6)

                        Rectangle {
                            width: window.s(6)
                            height: window.s(6)
                            radius: window.s(3)
                            color: window.extMonitorName !== ""
                                ? (window.themeColors.green || "#a6e3a1")
                                : (window.themeColors.subtext1 || "#939182")
                        }

                        Text {
                            text: window.extMonitorName !== ""
                                ? (window.extMonitorName + " · " + window.extMonitorRes + (window.extMonitorRefresh !== "" ? ("@" + window.extMonitorRefresh) : ""))
                                : (window.laptopName + " · " + window.laptopRes + " (Single Display)")
                            font.family: window.fontMono
                            font.pixelSize: window.s(10)
                            color: window.themeColors.subtext0 || "#c9c7b6"
                        }
                    }
                }

                // Hairline bottom separator
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.35)
                }
            }

            // 2. Presets List with Sliding Highlight
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Inset padding container
                Item {
                    id: listViewport
                    anchors.fill: parent
                    anchors.margins: window.s(10)

                    readonly property real rowHeight: window.s(54)
                    readonly property real rowSpacing: window.s(4)

                    // Kinetic Sliding Highlight Surface (Single elevation, no border clutter)
                    Rectangle {
                        id: slidingIndicator
                        x: 0
                        width: listViewport.width
                        height: listViewport.rowHeight
                        y: window.selectedIndex * (listViewport.rowHeight + listViewport.rowSpacing)
                        radius: window.s(6)
                        color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.65)

                        Behavior on y {
                            NumberAnimation {
                                duration: 130
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Left focus edge accent
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: window.s(8)
                            width: window.s(2)
                            radius: window.s(1)
                            color: window.themeColors.mauve || "#cacb77"
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: listViewport.rowSpacing

                        Repeater {
                            model: window.modesList

                            delegate: Item {
                                id: rowItem
                                Layout.fillWidth: true
                                Layout.preferredHeight: listViewport.rowHeight

                                readonly property bool isCurrent: (window.currentMode === modelData.modeId)
                                readonly property bool isSelected: (window.selectedIndex === index)
                                readonly property bool isAvailable: (modelData.modeId === "laptop_only" || window.extMonitorName !== "")

                                opacity: isAvailable ? 1.0 : 0.40
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                scale: rowMouseArea.pressed ? 0.985 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                MouseArea {
                                    id: rowMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        window.selectedIndex = index;
                                        window.previewMode = modelData.modeId;
                                    }
                                    onClicked: {
                                        window.selectedIndex = index;
                                        window.selectMode(modelData.arg);
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: window.s(14)
                                    anchors.rightMargin: window.s(14)
                                    spacing: window.s(12)

                                    // Keycap Badge
                                    Rectangle {
                                        width: window.s(22)
                                        height: window.s(22)
                                        radius: window.s(4)
                                        color: rowItem.isSelected
                                            ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.20)
                                            : Qt.alpha(window.themeColors.surface0 || "#202018", 0.90)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.key
                                            font.family: window.fontMono
                                            font.pixelSize: window.s(10)
                                            font.weight: Font.Bold
                                            color: rowItem.isSelected
                                                ? (window.themeColors.mauve || "#cacb77")
                                                : (window.themeColors.subtext0 || "#c9c7b6")
                                        }
                                    }

                                    // Abstract Display Topology Glyph (Pure geometry, zero toy skeuomorphism)
                                    Item {
                                        width: window.s(40)
                                        height: window.s(26)

                                        // Mode: Laptop display only
                                        Row {
                                            visible: modelData.modeId === "laptop_only"
                                            anchors.centerIn: parent
                                            spacing: window.s(4)

                                            // Internal screen (Active)
                                            Rectangle {
                                                width: window.s(20)
                                                height: window.s(14)
                                                radius: window.s(2)
                                                color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.85)
                                            }
                                            // External screen (Inactive / Hollow)
                                            Rectangle {
                                                width: window.s(14)
                                                height: window.s(14)
                                                radius: window.s(2)
                                                color: "transparent"
                                                border.width: 1
                                                border.color: Qt.alpha(window.themeColors.subtext1 || "#939182", 0.25)
                                            }
                                        }

                                        // Mode: Mirror display (Twin overlapping screens)
                                        Item {
                                            visible: modelData.modeId === "mirror"
                                            anchors.centerIn: parent
                                            width: window.s(32)
                                            height: window.s(20)

                                            Rectangle {
                                                x: 0
                                                y: window.s(4)
                                                width: window.s(18)
                                                height: window.s(13)
                                                radius: window.s(2)
                                                color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.50)
                                            }
                                            Rectangle {
                                                x: window.s(12)
                                                y: 0
                                                width: window.s(18)
                                                height: window.s(13)
                                                radius: window.s(2)
                                                color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.90)
                                            }
                                        }

                                        // Mode: Extend desktop (Orientation dynamic tiles)
                                        Item {
                                            visible: modelData.modeId === "extend"
                                            anchors.centerIn: parent
                                            width: window.s(36)
                                            height: window.s(22)

                                            // Left configuration: [Ext] [Laptop]
                                            Row {
                                                visible: window.extendPosition === "left"
                                                anchors.centerIn: parent
                                                spacing: window.s(3)

                                                Rectangle {
                                                    width: window.s(16)
                                                    height: window.s(14)
                                                    radius: window.s(2)
                                                    color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.90)
                                                }
                                                Rectangle {
                                                    width: window.s(16)
                                                    height: window.s(14)
                                                    radius: window.s(2)
                                                    color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.50)
                                                }
                                            }

                                            // Right configuration: [Laptop] [Ext]
                                            Row {
                                                visible: window.extendPosition === "right"
                                                anchors.centerIn: parent
                                                spacing: window.s(3)

                                                Rectangle {
                                                    width: window.s(16)
                                                    height: window.s(14)
                                                    radius: window.s(2)
                                                    color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.50)
                                                }
                                                Rectangle {
                                                    width: window.s(16)
                                                    height: window.s(14)
                                                    radius: window.s(2)
                                                    color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.90)
                                                }
                                            }

                                            // Top configuration: [Ext] stacked over [Laptop]
                                            Column {
                                                visible: window.extendPosition === "top"
                                                anchors.centerIn: parent
                                                spacing: window.s(2)

                                                Rectangle {
                                                    width: window.s(18)
                                                    height: window.s(9)
                                                    radius: window.s(2)
                                                    color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.90)
                                                }
                                                Rectangle {
                                                    width: window.s(18)
                                                    height: window.s(9)
                                                    radius: window.s(2)
                                                    color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.50)
                                                }
                                            }
                                        }

                                        // Mode: External display only
                                        Row {
                                            visible: modelData.modeId === "projector_only"
                                            anchors.centerIn: parent
                                            spacing: window.s(4)

                                            // Internal screen (Hollow / Off)
                                            Rectangle {
                                                width: window.s(14)
                                                height: window.s(14)
                                                radius: window.s(2)
                                                color: "transparent"
                                                border.width: 1
                                                border.color: Qt.alpha(window.themeColors.subtext1 || "#939182", 0.25)
                                            }
                                            // External screen (Active)
                                            Rectangle {
                                                width: window.s(20)
                                                height: window.s(14)
                                                radius: window.s(2)
                                                color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.85)
                                            }
                                        }
                                    }

                                    // Mode Title & Description (Human Sans-Serif)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: window.s(1)

                                        RowLayout {
                                            spacing: window.s(6)

                                            Text {
                                                text: (window.applyingMode && rowItem.isSelected)
                                                    ? "Applying changes…"
                                                    : modelData.title
                                                font.family: window.fontSans
                                                font.pixelSize: window.s(12)
                                                font.weight: Font.DemiBold
                                                color: (window.applyingMode && rowItem.isSelected)
                                                    ? (window.themeColors.mauve || "#cacb77")
                                                    : (rowItem.isSelected
                                                        ? (window.themeColors.text || "#e6e3d5")
                                                        : (window.themeColors.subtext0 || "#c9c7b6"))
                                            }

                                            // Busy indicator dot when applying
                                            Rectangle {
                                                visible: window.applyingMode && rowItem.isSelected
                                                width: window.s(5)
                                                height: window.s(5)
                                                radius: window.s(2.5)
                                                color: window.themeColors.mauve || "#cacb77"

                                                SequentialAnimation on opacity {
                                                    running: window.applyingMode && rowItem.isSelected
                                                    loops: Animation.Infinite
                                                    NumberAnimation { from: 0.3; to: 1.0; duration: 300 }
                                                    NumberAnimation { from: 1.0; to: 0.3; duration: 300 }
                                                }
                                            }
                                        }

                                        Text {
                                            text: {
                                                if (!rowItem.isAvailable) return "External display disconnected";
                                                if (modelData.modeId === "extend") {
                                                    if (window.extendPosition === "right") return "Laptop on left · External on right";
                                                    if (window.extendPosition === "top") return "External on top · Laptop below";
                                                    return "External on left · Laptop on right";
                                                }
                                                return modelData.desc;
                                            }
                                            font.family: window.fontSans
                                            font.pixelSize: window.s(10)
                                            font.weight: Font.Normal
                                            color: !rowItem.isAvailable
                                                ? Qt.alpha(window.themeColors.peach || "#f38ba8", 0.8)
                                                : (window.themeColors.subtext1 || "#939182")
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Position Cycle Chip for Extend Mode
                                    Rectangle {
                                        visible: modelData.modeId === "extend" && rowItem.isAvailable
                                        implicitHeight: window.s(22)
                                        implicitWidth: chipRow.implicitWidth + window.s(14)
                                        radius: window.s(4)
                                        color: chipMa.pressed
                                            ? Qt.alpha(window.themeColors.mauve || "#cacb77", 0.25)
                                            : (chipMa.containsMouse
                                                ? Qt.alpha(window.themeColors.surface2 || "#36352c", 0.90)
                                                : Qt.alpha(window.themeColors.surface0 || "#202018", 0.85))

                                        scale: chipMa.pressed ? 0.94 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 80 } }

                                        MouseArea {
                                            id: chipMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: window.cycleExtendPosition()
                                        }

                                        RowLayout {
                                            id: chipRow
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
                                                font.pixelSize: window.s(9)
                                                font.weight: Font.Bold
                                                color: window.themeColors.text || "#e6e3d5"
                                            }
                                            Text {
                                                text: "[S]"
                                                font.family: window.fontMono
                                                font.pixelSize: window.s(8)
                                                color: window.themeColors.subtext1 || "#939182"
                                            }
                                        }
                                    }

                                    // Active Status Tag (Current layout)
                                    Rectangle {
                                        visible: rowItem.isCurrent && (modelData.modeId !== "extend" || !rowItem.isAvailable)
                                        implicitHeight: window.s(18)
                                        implicitWidth: activeLabel.implicitWidth + window.s(12)
                                        radius: window.s(4)
                                        color: Qt.alpha(window.themeColors.mauve || "#cacb77", 0.15)

                                        Text {
                                            id: activeLabel
                                            anchors.centerIn: parent
                                            text: "Active"
                                            font.family: window.fontSans
                                            font.pixelSize: window.s(9)
                                            font.weight: Font.DemiBold
                                            color: window.themeColors.mauve || "#cacb77"
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
                Layout.preferredHeight: window.s(34)
                color: "transparent"

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.alpha(window.themeColors.surface1 || "#2b2a22", 0.25)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.s(16)
                    anchors.rightMargin: window.s(16)
                    spacing: window.s(12)

                    RowLayout {
                        spacing: window.s(4)
                        Text {
                            text: "1-4"
                            font.family: window.fontMono
                            font.pixelSize: window.s(9)
                            font.weight: Font.Bold
                            color: window.themeColors.subtext0 || "#c9c7b6"
                        }
                        Text {
                            text: "Select"
                            font.family: window.fontSans
                            font.pixelSize: window.s(9.5)
                            color: window.themeColors.subtext1 || "#939182"
                        }
                    }

                    Text {
                        text: "·"
                        font.pixelSize: window.s(9)
                        color: window.themeColors.surface2 || "#36352c"
                    }

                    RowLayout {
                        spacing: window.s(4)
                        Text {
                            text: "S / Tab"
                            font.family: window.fontMono
                            font.pixelSize: window.s(9)
                            font.weight: Font.Bold
                            color: window.themeColors.subtext0 || "#c9c7b6"
                        }
                        Text {
                            text: "Swap Position"
                            font.family: window.fontSans
                            font.pixelSize: window.s(9.5)
                            color: window.themeColors.subtext1 || "#939182"
                        }
                    }

                    Text {
                        text: "·"
                        font.pixelSize: window.s(9)
                        color: window.themeColors.surface2 || "#36352c"
                    }

                    RowLayout {
                        spacing: window.s(4)
                        Text {
                            text: "↵"
                            font.family: window.fontMono
                            font.pixelSize: window.s(9)
                            font.weight: Font.Bold
                            color: window.themeColors.subtext0 || "#c9c7b6"
                        }
                        Text {
                            text: "Apply"
                            font.family: window.fontSans
                            font.pixelSize: window.s(9.5)
                            color: window.themeColors.subtext1 || "#939182"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: window.s(4)
                        Text {
                            text: "Esc"
                            font.family: window.fontMono
                            font.pixelSize: window.s(9)
                            font.weight: Font.Bold
                            color: window.themeColors.subtext0 || "#c9c7b6"
                        }
                        Text {
                            text: "Close"
                            font.family: window.fontSans
                            font.pixelSize: window.s(9.5)
                            color: window.themeColors.subtext1 || "#939182"
                        }
                    }
                }
            }
        }
    }
}
