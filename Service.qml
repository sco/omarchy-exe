import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var settings: ({})
  property var vms: []
  property bool refreshing: false
  property string lastError: ""
  property string actionStatus: ""
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 30, 5, 3600)
  readonly property bool busy: listProcess.running || actionProcess.running

  property string _listOutput: ""
  property string _listError: ""
  property string _actionOutput: ""
  property string _actionError: ""
  property string _actionLabel: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(min, Math.min(max, value))
  }

  function compactError(value, fallback) {
    var text = String(value || "").replace(/\s+/g, " ").trim()
    if (text === "") text = fallback
    return text.length > 180 ? text.substring(0, 177) + "…" : text
  }

  function refresh() {
    if (listProcess.running) return
    _listOutput = ""
    _listError = ""
    refreshing = true
    listProcess.command = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "exe.dev", "ls", "--json"]
    listProcess.running = true
  }

  function applyList(raw) {
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      var records = parsed instanceof Array ? parsed : (parsed.vms instanceof Array ? parsed.vms : [])
      var next = []
      for (var i = 0; i < records.length; i++) {
        var vm = records[i] || {}
        next.push({
          vm_name: String(vm.vm_name || vm.name || "Unnamed VM"),
          status: String(vm.status || "unknown"),
          region_display: String(vm.region_display || vm.region || ""),
          ssh_dest: String(vm.ssh_dest || ""),
          https_url: String(vm.https_url || "")
        })
      }
      vms = next
      lastError = ""
    } catch (error) {
      lastError = "exe.dev returned invalid JSON: " + compactError(error, "parse failed")
    }
  }

  function openTerminal(vm) {
    if (!vm || !vm.ssh_dest) {
      lastError = "This VM has no SSH destination."
      return
    }
    Quickshell.execDetached(["omarchy-launch-terminal", "ssh", String(vm.ssh_dest)])
  }

  function openHttps(vm) {
    if (!vm || !vm.https_url) {
      lastError = "This VM has no HTTPS URL."
      return
    }
    Qt.openUrlExternally(String(vm.https_url))
  }

  function copySshDestination(vm) {
    if (!vm || !vm.ssh_dest) {
      lastError = "This VM has no SSH destination to copy."
      return
    }
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(String(vm.ssh_dest)) + " | wl-copy"])
    showStatus("Copied " + String(vm.ssh_dest))
  }

  function restartVm(vm) {
    if (!vm || !vm.vm_name) return
    runAction(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "exe.dev", "restart", String(vm.vm_name), "--json"], "Restarting " + String(vm.vm_name) + "…")
  }

  function createVm() {
    runAction(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "exe.dev", "new", "--json"], "Creating a VM…")
  }

  function runAction(command, label) {
    if (actionProcess.running) return
    _actionOutput = ""
    _actionError = ""
    _actionLabel = label
    actionStatus = label
    lastError = ""
    actionProcess.command = command
    actionProcess.running = true
  }

  function showStatus(message) {
    actionStatus = message
    statusTimer.restart()
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: delayedRefresh
    interval: 900
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: statusTimer
    interval: 2400
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Process {
    id: listProcess
    running: false
    command: []
    stdout: StdioCollector { id: listStdout; waitForEnd: true; onStreamFinished: root._listOutput = text }
    stderr: StdioCollector { id: listStderr; waitForEnd: true; onStreamFinished: root._listError = text }
    onExited: function(exitCode) {
      root.refreshing = false
      var stdout = String(listStdout.text || root._listOutput || "")
      var stderr = String(listStderr.text || root._listError || "")
      if (exitCode === 0) root.applyList(stdout)
      else root.lastError = root.compactError(stderr || stdout, "Could not reach exe.dev. Check your network, SSH key, and exe.dev access.")
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true; onStreamFinished: root._actionOutput = text }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true; onStreamFinished: root._actionError = text }
    onExited: function(exitCode) {
      var stdout = String(actionStdout.text || root._actionOutput || "")
      var stderr = String(actionStderr.text || root._actionError || "")
      if (exitCode === 0) {
        root.lastError = ""
        root.showStatus(root._actionLabel.replace(/…$/, "") + " complete")
        delayedRefresh.restart()
      } else {
        root.actionStatus = ""
        root.lastError = root.compactError(stderr || stdout, "exe.dev command failed. Check SSH and account access.")
      }
    }
  }
}
