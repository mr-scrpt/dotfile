import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Bar toggle for the big monitor. State is read live from Hyprland
// (a disabled output is absent from Hyprland.monitors), the click runs
// ~/.local/bin/omarchy-big-monitor which flips the flag and reloads Hyprland.
BarWidget {
  id: root
  moduleName: "mr.big-monitor"

  readonly property string output: String(setting("output", "DP-1"))

  readonly property bool monitorOn: {
    var list = Hyprland.monitors ? Hyprland.monitors.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].name === root.output) return true
    }
    return false
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.monitorOn ? "󰍹" : "󰶐"
    // Stock toggle look (night light, stay awake): foreground when on,
    // dimmed when off. `active` would paint it in bar.urgent (red).
    useActiveColor: false
    dimmed: !root.monitorOn
    tooltipText: root.monitorOn
      ? "Big monitor (" + root.output + ") is on — click to turn off"
      : "Big monitor (" + root.output + ") is off — click to turn on"
    onPressed: if (root.bar) root.bar.run("omarchy-big-monitor toggle")
  }
}
