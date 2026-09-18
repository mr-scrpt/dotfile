import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Local LLM (llama.cpp) bar widget. State comes from `llama-local-status`
// (JSON: state off|loading|ready, tooltip). Left click opens Hermes on the
// local profile, right click loads/unloads the model.
BarWidget {
  id: root
  moduleName: "mr.local-llm"

  property string state: "off"
  property string tooltip: "Local LLM"
  property bool pulse: false
  readonly property color green: "#9ece6a"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰘚"
    // Stock toggle look: dimmed when off; green (not bar.urgent) when the
    // model is loaded; blinking while it loads.
    active: root.state === "ready"
    activeColor: root.green
    dimmed: root.state === "off" || (root.state === "loading" && root.pulse)
    tooltipText: root.tooltip
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("llama-local-status toggle")
      else root.bar.run("hermes-local-launch")
    }
  }

  Timer {
    interval: 500
    running: root.state === "loading"
    repeat: true
    onTriggered: root.pulse = !root.pulse
    onRunningChanged: if (!running) root.pulse = false
  }

  Process {
    id: proc
    command: ["bash", "-lc", "~/.local/bin/llama-local-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.state = d.state || "off"
          root.tooltip = d.tooltip || "Local LLM"
        } catch (e) { root.state = "off" }
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: proc.running = true
  }
}
