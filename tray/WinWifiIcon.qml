import QtQuick
import Quickshell
import qs.Commons

// Network glyph, drawn rather than glyph-based so it reads the same whatever
// icon font is installed.
//
// A fan of arcs above a dot. The fan's vertical centre is recomputed from the
// number of arcs actually drawn, so a weak signal (fewer arcs) still sits on
// the same centre line as the speaker and battery icons beside it.
Canvas {
  id: root

  property var bar: null
  property string kind: "disconnected"
  property int signalStrength: -1

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property bool wired: kind === "ethernet"
  readonly property int level: kind !== "wifi"
    ? 0
    : Math.max(1, Math.min(4, Math.round(signalStrength / 25)))
  readonly property real span: 4 + Math.max(0, level - 1) * 3.8

  width: 24
  height: 24

  onKindChanged: requestPaint()
  onLevelChanged: requestPaint()
  onSpanChanged: requestPaint()
  onFgChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = root.fg
    ctx.fillStyle = root.fg
    ctx.lineWidth = 1.8
    ctx.lineCap = "round"

    if (root.wired) {
      // Wired: a NIC with its three latch nubs.
      ctx.strokeRect(5, 8, 14, 9)
      ctx.beginPath()
      ctx.moveTo(9, 8); ctx.lineTo(9, 11.5)
      ctx.moveTo(12, 8); ctx.lineTo(12, 11.5)
      ctx.moveTo(15, 8); ctx.lineTo(15, 11.5)
      ctx.stroke()
      return
    }

    var cx = width / 2
    var cy = height / 2 + (root.span - 2) / 2
    for (var i = 0; i < root.level; i++) {
      var r = 4 + i * 3.8
      ctx.beginPath()
      ctx.arc(cx, cy, r, Math.PI * 1.25, Math.PI * 1.75)
      ctx.stroke()
    }
    ctx.beginPath()
    ctx.arc(cx, cy, 2, 0, Math.PI * 2)
    ctx.fill()
  }
}
