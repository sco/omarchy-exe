import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property int refreshIntervalSec: 30
  property var vms: []
  property bool refreshing: false
  property bool needsAuth: false
  property string lastError: ""
  property string actionStatus: ""

  property string operation: ""
  property string successMessage: ""

  function sshCommand(args) {
    return ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "exe.dev"].concat(args)
  }

  function compact(value, fallback) {
    var text = String(value || "").replace(/\s+/g, " ").trim() || fallback
    return text.length > 180 ? text.substring(0, 177) + "…" : text
  }

  function run(command, nextOperation, pending, success) {
    if (process.running) return
    operation = nextOperation
    successMessage = success || ""
    actionStatus = pending || ""
    lastError = ""
    process.command = command
    process.running = true
  }

  function refresh() {
    if (process.running) return
    refreshing = true
    run(sshCommand(["ls", "--json"]), "list", "", "")
  }

  function applyList(raw) {
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      var records = Array.isArray(parsed) ? parsed : (Array.isArray(parsed.vms) ? parsed.vms : [])
      vms = records.map(function(vm) {
        return {
          vm_name: String(vm.vm_name || vm.name || "Unnamed VM"),
          status: String(vm.status || "unknown"),
          region_display: String(vm.region_display || vm.region || ""),
          ssh_dest: String(vm.ssh_dest || ""),
          https_url: String(vm.https_url || "")
        }
      })
      needsAuth = false
      lastError = ""
    } catch (error) {
      lastError = "exe.dev returned invalid JSON: " + compact(error, "parse failed")
    }
  }

  function applyFailure(raw) {
    var message = compact(raw, "Could not reach exe.dev.")
    var lower = message.toLowerCase()
    needsAuth = lower.indexOf("permission denied") !== -1
      || lower.indexOf("register") !== -1
      || lower.indexOf("authentication failed") !== -1
    lastError = needsAuth ? "" : message
  }

  function openSetup() {
    Quickshell.execDetached(["omarchy-launch-terminal", "ssh", "exe.dev"])
  }

  function openSignIn() {
    Qt.openUrlExternally("https://exe.dev/auth")
  }

  function openTerminal(vm) {
    if (vm && vm.ssh_dest) Quickshell.execDetached(["omarchy-launch-terminal", "ssh", String(vm.ssh_dest)])
  }

  function openHttps(vm) {
    if (vm && vm.https_url) Qt.openUrlExternally(String(vm.https_url))
    else lastError = "This VM has no HTTPS URL."
  }

  function copySshDestination(vm) {
    if (!vm || !vm.ssh_dest) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(String(vm.ssh_dest)) + " | wl-copy"])
    showStatus("Copied " + String(vm.ssh_dest))
  }

  function restartVm(vm) {
    if (vm && vm.vm_name) run(sshCommand(["restart", String(vm.vm_name), "--json"]), "action", "Restarting " + vm.vm_name + "…", "Restarted " + vm.vm_name)
  }

  function createVm() {
    run(sshCommand(["new", "--json"]), "action", "Creating a VM…", "VM created")
  }

  function showStatus(message) {
    actionStatus = message
    statusTimer.restart()
  }

  Timer {
    interval: Math.max(5, root.refreshIntervalSec) * 1000
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
    id: process
    running: false
    command: []
    stdout: StdioCollector { id: outputCollector; waitForEnd: true }
    stderr: StdioCollector { id: errorCollector; waitForEnd: true }
    onExited: function(exitCode) {
      var currentOperation = root.operation
      var output = String(outputCollector.text || "")
      var error = String(errorCollector.text || "")
      root.refreshing = false
      root.actionStatus = ""

      if (exitCode !== 0) {
        root.applyFailure(error || output)
      } else if (currentOperation === "list") {
        root.applyList(output)
      } else {
        root.needsAuth = false
        root.lastError = ""
        root.showStatus(root.successMessage)
        delayedRefresh.restart()
      }
    }
  }
}
