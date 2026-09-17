import QtQuick
import Quickshell.Io

// Local LLM (llama.cpp) bar widget: green when the model is loaded, dim when off.
Item {
  id: root
  property var bar
  property string moduleName
  property var settings

  property string state: "off"     // off | loading | ready
  property string tooltip: "Local LLM"
  readonly property color green: "#9ece6a"

  implicitWidth: 28
  implicitHeight: bar ? bar.barSize : 26

  Text {
    id: icon
    anchors.centerIn: parent
    text: root.state === "off" ? "󰘚" : "󰘚"
    color: root.state === "ready" ? root.green : (bar ? bar.foreground : "white")
    opacity: root.state === "off" ? 0.45 : 1
    font.family: bar ? bar.fontFamily : "monospace"
    font.pixelSize: 14
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on opacity { NumberAnimation { duration: 160 } }
    SequentialAnimation on opacity {
      running: root.state === "loading"
      loops: Animation.Infinite
      NumberAnimation { to: 0.3; duration: 500 }
      NumberAnimation { to: 1.0; duration: 500 }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onEntered: if (bar) bar.showTooltip(root, root.tooltip)
    onExited: if (bar) bar.hideTooltip(root)
    onClicked: function(mouse) {
      if (!bar) return
      if (mouse.button === Qt.RightButton) bar.run("llama-local-status toggle")
      else bar.run("hermes-local-launch")
    }
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
