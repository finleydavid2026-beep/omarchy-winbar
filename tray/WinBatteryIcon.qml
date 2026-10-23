import QtQuick
import Quickshell
import qs.Commons

// Battery glyph, drawn rather than glyph-based: a rounded cell with a terminal
// nub, a fill level, and a bolt knocked out of the fill while charging. The
// cell is centred on the canvas mid-line so it shares a centre with the wifi
// and speaker icons beside it.
Canvas {
  id: root

  property var bar: null
  property bool present: true
  property real fraction: 0
  property bool charging: false
  property bool full: false

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  // The bar surface, used to knock the bolt out of the fill so it stays
  // legible when the cell is nearly full.
  readonly property color hole: bar ? bar.background : Color.background

  width: 22
  height: 20

  onPresentChanged: requestPaint()
  onFractionChanged: requestPaint()
  onChargingChanged: requestPaint()
  onFullChanged: requestPaint()
  onFgChanged: requestPaint()
  onHoleChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = root.fg
    ctx.fillStyle = root.fg
    ctx.lineWidth = 1.4
    ctx.lineJoin = "round"

    // Cell body (17x11, centred vertically) and terminal nub.
    ctx.strokeRect(1, 4.5, 17, 11)
    ctx.fillRect(19, 8.2, 2, 3.6)

    if (!root.present) return

    var level = Math.max(0, Math.min(1, root.fraction))
    var w = Math.round((17 - 3) * level)
    if (w > 0) ctx.fillRect(2.5, 6, w, 8)

    if (root.charging) {
      ctx.fillStyle = root.hole
      ctx.beginPath()
      ctx.moveTo(10.6, 5.4); ctx.lineTo(7.2, 10.4); ctx.lineTo(9.6, 10.4)
      ctx.lineTo(8.4, 14.6); ctx.lineTo(12.2, 9); ctx.lineTo(9.8, 9)
      ctx.closePath()
      ctx.fill()
    }
  }
}
