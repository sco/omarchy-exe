import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property int refreshIntervalSec: 30
  property int tokenLifetimeDays: 90
  property var vms: []
  property bool refreshing: false
  property bool needsAuth: false
  property string username: ""
  property string lastError: ""
  property string actionStatus: ""

  property string operation: ""
  property string successMessage: ""
  readonly property string apiScript: "token=$(secret-tool lookup service exe.dev application sco.exe 2>/dev/null) || exit 77; [ -n \"$token\" ] || exit 77; printf 'Authorization: Bearer %s\\n' \"$token\" | curl --fail-with-body --silent --show-error --request POST --header @- --data-binary \"$1\" https://exe.dev/exec"

  function apiCommand(args) {
    var command = args.map(function(value) { return Util.shellQuote(String(value)) }).join(" ")
    return ["bash", "-lc", apiScript, "bash", command]
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
    run(apiCommand(["ls", "--json"]), "list", "", "")
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
          https_url: String(vm.https_url || ""),
          shelley_url: String(vm.shelley_url || ""),
          emoji: String(vm.emoji || "")
        }
      })
      needsAuth = false
      lastError = ""
    } catch (error) {
      lastError = "exe.dev returned invalid JSON: " + compact(error, "parse failed")
    }
  }

  function applyFailure(exitCode, raw) {
    var message = compact(raw, "Could not reach exe.dev.")
    var lower = message.toLowerCase()
    needsAuth = exitCode === 77
      || lower.indexOf("401") !== -1
      || lower.indexOf("invalid token") !== -1
      || lower.indexOf("unauthorized") !== -1
    lastError = needsAuth ? "" : message
  }

  function openSetup() {
    var lifetime = Math.max(1, Math.min(365, parseInt(String(tokenLifetimeDays), 10) || 90))
    var setup = "set -e; token=$(ssh exe.dev ssh-key generate-api-key --label=omarchy-exe --cmds=ls,new,restart,whoami --exp=" + lifetime + "d | grep -oE 'exe[01]\\.[A-Za-z0-9._-]+' | tail -1); [ -n \"$token\" ]; printf %s \"$token\" | secret-tool store --label='exe.dev Omarchy plugin' service exe.dev application sco.exe; omarchy-shell sco.exe open"
    Quickshell.execDetached(["omarchy-launch-terminal", "bash", "-lc", setup])
  }

  function openSignIn() {
    Qt.openUrlExternally("https://exe.dev/auth")
  }

  function openTerminal(vm) {
    if (vm && vm.ssh_dest) Quickshell.execDetached(["omarchy-launch-terminal", "ssh", String(vm.ssh_dest)])
  }

  function openLobby() {
    Quickshell.execDetached(["omarchy-launch-terminal", "ssh", "exe.dev"])
  }

  function openHttps(vm) {
    if (vm && vm.https_url) Qt.openUrlExternally(String(vm.https_url))
    else lastError = "This VM has no HTTPS URL."
  }

  function openShelley(vm) {
    if (vm && vm.shelley_url) Qt.openUrlExternally(String(vm.shelley_url))
    else lastError = "Shelley is not available on this VM."
  }

  function copySshDestination(vm) {
    if (!vm || !vm.ssh_dest) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(String(vm.ssh_dest)) + " | wl-copy"])
    showStatus("Copied " + String(vm.ssh_dest))
  }

  function restartVm(vm) {
    if (vm && vm.vm_name) run(apiCommand(["restart", String(vm.vm_name), "--json"]), "action", "Restarting " + vm.vm_name + "…", "Restarted " + vm.vm_name)
  }

  function createVm(name, prompt) {
    var args = ["new", "--json"]
    var vmName = String(name || "").trim()
    var vmPrompt = String(prompt || "").trim()
    if (vmName) args.push("--name=" + vmName)
    if (vmPrompt) args.push("--prompt=" + vmPrompt)
    run(apiCommand(args), "action", "Creating " + (vmName || "VM") + "…", "Created " + (vmName || "VM"))
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

  Process {
    id: identityProcess
    running: true
    command: ["bash", "-lc", "token=$(secret-tool lookup service exe.dev application sco.exe 2>/dev/null); if [ -n \"$token\" ]; then response=$(printf 'Authorization: Bearer %s\\n' \"$token\" | curl --fail-with-body --silent --request POST --header @- --data-binary 'whoami --json' https://exe.dev/exec 2>/dev/null) && { printf %s \"$response\"; exit; }; fi; ssh -G exe.dev 2>/dev/null | sed -n 's/^user //p' | head -1"]
    stdout: StdioCollector { id: identityOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var raw = String(identityOutput.text || "").trim()
      try {
        var identity = JSON.parse(raw)
        root.username = String(identity.username || identity.user || identity.name || identity.email || "").split("@")[0]
      } catch (error) {
        root.username = raw
      }
    }
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
        root.applyFailure(exitCode, output || error)
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
