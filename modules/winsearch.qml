import QtQuick
import Quickshell
import qs.Commons

// Search pill.
//
// A rounded field with a drawn magnifier and placeholder text. Clicking it
// opens the Omarchy menu on the Apps list, whose own search box takes the
// keyboard straight away, so typing filters installed apps.
Item {
  id: root

  property var bar: null
  property string moduleName: "winsearch"
  property var settings: ({})

  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property color fg: bar ? bar.barForeground : Color.foreground

  implicitWidth: 300
  implicitHeight: barSize

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, mouse.containsMouse ? 0.10 : 0.05)
    border.width: 1
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, mouse.containsMouse ? 0.28 : 0.16)

    Behavior on color {
      ColorAnimation { duration: 130 }
    }
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 12
    spacing: 7

    // Magnifier, drawn so it renders regardless of the icon font in use.
    Item {
      width: 13
      height: 13
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        width: 9
        height: 9
        radius: 9 / 2
        color: "transparent"
        border.width: 1.4
        border.color: root.fg
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        width: 5
        height: 1.6
        radius: 1
        color: root.fg
        rotation: 45
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 5.3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 5.3
      }
    }

    Text {
      text: "Type here to search"
      color: root.fg
      opacity: 0.62
      font.family: root.bar ? root.bar.fontFamily : "monospace"
      font.pixelSize: 12
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
      renderType: Text.NativeRendering
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function() {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"apps\"}'")
    }
  }
}
