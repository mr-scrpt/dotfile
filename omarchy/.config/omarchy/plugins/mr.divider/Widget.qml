import QtQuick
import qs.Commons
import qs.Ui

// A thin rule that separates groups of bar widgets. Mirrors PanelSeparator's
// alpha-on-foreground tint so the line reads against any theme, and flips its
// orientation with the bar the same way the stock widgets do.
BarWidget {
  id: root
  moduleName: "mr.divider"

  readonly property int thickness: Number(setting("thickness", 1))
  readonly property int extent: Number(setting("extent", 12))
  readonly property int gap: Number(setting("gap", 8))
  readonly property real strength: Number(setting("strength", 0.35))

  implicitWidth: vertical ? barSize : thickness + gap * 2
  implicitHeight: vertical ? thickness + gap * 2 : barSize

  Rectangle {
    anchors.centerIn: parent
    width: root.vertical ? root.extent : root.thickness
    height: root.vertical ? root.thickness : root.extent
    radius: root.thickness / 2
    color: {
      var fg = root.bar ? root.bar.foreground : Color.foreground
      return Qt.rgba(fg.r, fg.g, fg.b, root.strength)
    }
  }
}
