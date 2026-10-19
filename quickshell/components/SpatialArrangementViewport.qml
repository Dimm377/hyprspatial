import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: root
    Layout.preferredWidth: 390
    Layout.fillHeight: true
    color: Qt.alpha(root.themeColors.crust || "#14140c", 0.5)

    property var themeColors: ({})
    property string fontSans: "sans-serif"
    property string fontMono: "monospace"
    property string currentMode: "extend"
    property string previewMode: "extend"
    property string extendPosition: "left"
    property string extMonitorName: ""
    property string extMonitorRes: "1920 × 1080"
    property string extMonitorRefresh: ""
    property string laptopName: ""
    property string laptopRes: "1920 × 1080"
    property string laptopRefresh: ""

    // Spatial Geometry Canvas Container
    Item {
        id: canvasContainer
        anchors.fill: parent
        anchors.margins: 16

            // Elevated Surface with Soft Drop Shadow
            Rectangle {
                id: canvasBg
                anchors.fill: parent
                radius: 8
                color: Qt.alpha(root.themeColors.base || "#0f0f07", 0.8)
                border.width: 0

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.35
                    shadowBlur: 0.7
                    shadowVerticalOffset: 2.5
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
                    anchors.bottomMargin: 22
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    height: 1
                    color: Qt.alpha(root.themeColors.surface1 || "#2b2a22", 0.45)
                }

                // Subtle Elegant Projection Beam for Mirror Mode
                ProjectionBeam {
                    id: beamCanvas
                    themeColors: root.themeColors
                    active: (root.previewMode === "mirror")
                    startX: extSlot.x + projectorSlot.x + projectorSlot.lensX
                    startY: extSlot.y + projectorSlot.y + projectorSlot.lensY
                    targetX: laptopSlot.screenTargetX
                    targetYCenter: laptopSlot.screenCenterY
                    targetHalfHeight: laptopSlot.screenHalfHeight
                }

                // ─── 1. EXTERNAL DISPLAY SLOT (Monitor Stand OR Projector) ───
                Item {
                    id: extSlot
                    z: 2
                    width: 164
                    height: 104
                    x: {
                        if (root.previewMode === "extend") {
                            if (root.extendPosition === "right") {
                                return canvasSurface.width - width - 16;
                            } else if (root.extendPosition === "top") {
                                return Math.round((canvasSurface.width - width) / 2);
                            } else {
                                return 16;
                            }
                        }
                        return (root.previewMode === "projector_only") ? 22 : 16;
                    }
                    y: {
                        if (root.previewMode === "extend" && root.extendPosition === "top") {
                            return 6;
                        }
                        return parent.height - 22 - height;
                    }

                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    onXChanged: if (root.previewMode === "mirror") beamCanvas.requestPaint()
                    onYChanged: if (root.previewMode === "mirror") beamCanvas.requestPaint()

                    DesktopMonitorSlot {
                        anchors.horizontalCenter: parent.horizontalCenter
                        themeColors: root.themeColors
                        fontSans: root.fontSans
                        fontMono: root.fontMono
                        previewMode: root.previewMode
                        extendPosition: root.extendPosition
                        extMonitorName: root.extMonitorName
                        extMonitorRes: root.extMonitorRes
                        extMonitorRefresh: root.extMonitorRefresh
                    }

                    ProjectorSlot {
                        id: projectorSlot
                        anchors.horizontalCenter: parent.horizontalCenter
                        themeColors: root.themeColors
                        fontSans: root.fontSans
                        fontMono: root.fontMono
                        previewMode: root.previewMode
                        extMonitorName: root.extMonitorName
                        onYChanged: if (root.previewMode === "mirror") beamCanvas.requestPaint()
                    }
                }

                // ─── 2. LAPTOP DISPLAY SLOT (Lid + Chassis & Touchpad Notch) ───
                LaptopSlot {
                    id: laptopSlot
                    z: 2
                    themeColors: root.themeColors
                    fontSans: root.fontSans
                    fontMono: root.fontMono
                    previewMode: root.previewMode
                    extendPosition: root.extendPosition
                    laptopName: root.laptopName
                    laptopRes: root.laptopRes
                    laptopRefresh: root.laptopRefresh
                    onXChanged: if (root.previewMode === "mirror") beamCanvas.requestPaint()
                    onYChanged: if (root.previewMode === "mirror") beamCanvas.requestPaint()
                }
            }
        }
    }
