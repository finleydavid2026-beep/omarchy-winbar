import QtQuick
import Quickshell
import qs.Commons

// Windows "show desktop" sliver: the labelled strip at the far right edge of
// the taskbar. Clicking it minimises every window; clicking again puts them
// back. The label mirrors Windows' own minimise affordance.
Item {
  id: root

  property var bar: null
  property string moduleName: "windesktop"
  property var settings: ({})

  readonly property string home: Quickshell.env("HOME") || ""

  implicitWidth: 40
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.16 : 0.04)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.34 : 0.14)

    Behavior on color {
      ColorAnimation { duration: 130 }
    }
  }

  Text {
    textFormat: Text.PlainText
    text: "(min)"
    color: root.bar ? root.bar.barForeground : Color.foreground
    opacity: mouse.containsMouse ? 1 : 0.55
    font.family: root.bar ? root.bar.fontFamily : "monospace"
    font.pixelSize: 10
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
      if (!root.bar || !root.home) return
      root.bar.run("bash '" + root.home + "/.config/omarchy/bin/win-show-desktop.sh'")
    }
  }
}
