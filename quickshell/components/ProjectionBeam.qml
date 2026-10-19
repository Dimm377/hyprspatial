import QtQuick

Canvas {
    id: root
    anchors.fill: parent
    z: 1

    property var themeColors: ({})
    property bool active: false
    property real startX: 0
    property real startY: 0
    property real targetX: 0
    property real targetYCenter: 0
    property real targetHalfHeight: 30

    visible: opacity > 0.01
    opacity: active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    property real beamSpread: active ? 1.0 : 0.0
    Behavior on beamSpread { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    onBeamSpreadChanged: requestPaint()
    onActiveChanged: requestPaint()
    onStartXChanged: requestPaint()
    onStartYChanged: requestPaint()
    onTargetXChanged: requestPaint()
    onTargetYCenterChanged: requestPaint()

    onPaint: {
        let ctx = getContext("2d");
        if (!ctx) return;
        ctx.clearRect(0, 0, width, height);

        if (!active && beamSpread <= 0.005) return;

        let lx = startX;
        let ly = startY;
        let currentTx = lx + (targetX - lx) * (0.35 + 0.65 * beamSpread);
        let currentHalfH = targetHalfHeight * Math.max(0.10, beamSpread);
        let currentTargetY = ly + (targetYCenter - ly) * (0.35 + 0.65 * beamSpread);
        let tyTop = currentTargetY - currentHalfH;
        let tyBottom = currentTargetY + currentHalfH;

        let mColor = Qt.color(root.themeColors.mauve || "#cacb77");
        let mr = mColor.r;
        let mg = mColor.g;
        let mb = mColor.b;

        // 1. Soft glowing projection light cone gradient
        let grad = ctx.createLinearGradient(lx, ly, currentTx, currentTargetY);
        grad.addColorStop(0.0, Qt.rgba(mr, mg, mb, 0.24));
        grad.addColorStop(0.35, Qt.rgba(mr, mg, mb, 0.10));
        grad.addColorStop(0.75, Qt.rgba(mr, mg, mb, 0.03));
        grad.addColorStop(1.0, Qt.rgba(mr, mg, mb, 0.0));

        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.moveTo(lx, ly - 6);
        ctx.lineTo(currentTx, tyTop);
        ctx.lineTo(currentTx, tyBottom);
        ctx.lineTo(lx, ly + 6);
        ctx.closePath();
        ctx.fill();

        // 2. Focused central projection ray
        let lineGrad = ctx.createLinearGradient(lx, ly, currentTx, currentTargetY);
        lineGrad.addColorStop(0.0, Qt.rgba(mr, mg, mb, 0.35));
        lineGrad.addColorStop(0.60, Qt.rgba(mr, mg, mb, 0.08));
        lineGrad.addColorStop(1.0, Qt.rgba(mr, mg, mb, 0.0));
        ctx.strokeStyle = lineGrad;
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.moveTo(lx, ly);
        ctx.lineTo(currentTx, currentTargetY);
        ctx.stroke();

        // 3. Luminous lens aperture glow highlight
        let lensGlow = ctx.createRadialGradient(lx, ly, 1, lx, ly, 9);
        lensGlow.addColorStop(0.0, Qt.rgba(mr, mg, mb, 0.55));
        lensGlow.addColorStop(0.40, Qt.rgba(mr, mg, mb, 0.20));
        lensGlow.addColorStop(1.0, Qt.rgba(mr, mg, mb, 0.0));
        ctx.fillStyle = lensGlow;
        ctx.beginPath();
        ctx.arc(lx, ly, 9, 0, 2 * Math.PI);
        ctx.fill();
    }
}
