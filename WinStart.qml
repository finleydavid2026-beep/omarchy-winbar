import QtQuick
import Quickshell
import qs.Commons

// Windows-style taskbar start button.
//
// Carries the Omarchy mark (glyph U+E900 in the omarchy icon font) in the
// Omarchy brand green, and opens the Omarchy menu on click — the stand-in for
// a Start menu. Sized to one bar slot so it lines up with the tray icons.
//
// The root is a plain Item carrying the three properties the bar host injects
// (`bar`, `moduleName`, `settings`) rather than qs.Ui's BarWidget: BarWidget
// does not resolve from a third-party plugin's QML context, while these three
// are injected regardless.
//
// The glyph is written as an escape, never as a literal private-use character:
// a literal written through an editor can silently land on the wrong
// codepoint and render an unrelated icon.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property color fg: bar ? bar.barForeground : Color.foreground

  implicitWidth: barSize
  implicitHeight: barSize

  // Hover affordance: a soft rounded pill behind the mark.
  Rectangle {
    anchors.fill: parent
    radius: 3
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, mouse.containsMouse ? 0.14 : 0)

    Behavior on color {
      ColorAnimation { duration: 130 }
    }
  }

  Text {
    textFormat: Text.PlainText
    text: ""
    // Omarchy brand green, matching the reference mark.
    color: "#8bc957"
    font.family: "omarchy"
    font.pixelSize: Math.round(root.barSize * 0.62)
    anchors.centerIn: parent
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function() {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
