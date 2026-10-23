import QtQuick
import Quickshell
import qs.Commons

// Volume glyph, drawn rather than glyph-based: a speaker cone with one or two
// sound waves, or a cross when muted. One wave is always shown while there is
// audible output so the icon keeps the same width as its neighbours.
Canvas {
  id: root

  property var bar: null
  property bool hasOutput: true
  property bool muted: false
  property real volume: 0

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property int waves: (!hasOutput || muted)
    ? 0
    : (volume >= 0.67 ? 2 : 1)

  width: 20
  height: 20

  onHasOutputChanged: requestPaint()
  onMutedChanged: requestPaint()
  onVolumeChanged: requestPaint()
  onWavesChanged: requestPaint()
  onFgChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = root.fg
    ctx.fillStyle = root.fg
    ctx.lineWidth = 1.4
    ctx.lineCap = "round"

    // Speaker cone, vertically centred in the canvas.
    ctx.beginPath()
    ctx.moveTo(3.5, 7.5); ctx.lineTo(6, 7.5)
    ctx.lineTo(10, 4); ctx.lineTo(10, 16)
    ctx.lineTo(6, 12.5); ctx.lineTo(3.5, 12.5)
    ctx.closePath()
    ctx.fill()

    if (root.muted) {
      ctx.beginPath()
      ctx.moveTo(11.5, 6); ctx.lineTo(17.5, 14)
      ctx.moveTo(17.5, 6); ctx.lineTo(11.5, 14)
      ctx.stroke()
      return
    }

    for (var i = 0; i < root.waves; i++) {
      var r = 5.5 + i * 3.5
      ctx.beginPath()
      ctx.arc(10, 10, r, -Math.PI / 3, Math.PI / 3)
      ctx.stroke()
    }
  }
}
