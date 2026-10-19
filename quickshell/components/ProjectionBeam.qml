import QtQuick

Canvas {
    id: root
    anchors.fill: parent
    z: 0

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
        let currentHalfH = targetHalfHeight * Math.max(0.08, beamSpread);
        let tyTop = targetYCenter - currentHalfH;
        let tyBottom = targetYCenter + currentHalfH;

        let mColor = Qt.color(root.themeColors.mauve || "#cacb77");
        let mr = mColor.r;
        let mg = mColor.g;
        let mb = mColor.b;

        let grad = ctx.createLinearGradient(lx, ly, currentTx, ly);
        grad.addColorStop(0.0, Qt.rgba(mr, mg, mb, 0.15));
        grad.addColorStop(0.55, Qt.rgba(mr, mg, mb, 0.04));
        grad.addColorStop(1.0, Qt.rgba(mr, mg, mb, 0.0));

        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.moveTo(lx, ly - 4);
        ctx.lineTo(currentTx, tyTop);
        ctx.lineTo(currentTx, tyBottom);
        ctx.lineTo(lx, ly + 4);
        ctx.closePath();
        ctx.fill();

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
