import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "sco.exe"
  ipcTarget: "sco.exe"

  property int vmIndex: 0
  property bool cursorActive: false
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function selectedVm() {
    return exe.vms.length ? exe.vms[Math.max(0, Math.min(vmIndex, exe.vms.length - 1))] : null
  }

  function moveCursor(dy) {
    cursorActive = true
    if (!exe.needsAuth && exe.vms.length) vmIndex = Math.max(0, Math.min(exe.vms.length - 1, vmIndex + dy))
    scrollCursorIntoView()
  }

  function setCursor(index) {
    cursorActive = true
    vmIndex = index
    scrollCursorIntoView()
  }

  function activate() {
    if (exe.needsAuth) {
      exe.openSetup()
      close()
      return
    }
    var vm = selectedVm()
    if (vm) {
      exe.openTerminal(vm)
      close()
    }
  }

  function scrollCursorIntoView() {
    if (exe.needsAuth || !vmColumn || vmIndex < 0 || vmIndex >= vmColumn.children.length) return
    var item = vmColumn.children[vmIndex]
    Qt.callLater(function() {
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var margin = Style.space(6)
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (point.y < panelFlick.contentY + margin) panelFlick.contentY = Math.max(0, point.y - margin)
      else if (point.y + item.height > panelFlick.contentY + panelFlick.height - margin)
        panelFlick.contentY = Math.min(maxY, point.y + item.height + margin - panelFlick.height)
    })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    panelFlick.contentY = 0
    exe.refresh()
  }

  Service {
    id: exe
    refreshIntervalSec: root.setting("refreshIntervalSec", 30)
  }

  Connections {
    target: exe
    function onVmsChanged() { root.vmIndex = Math.max(0, Math.min(root.vmIndex, Math.max(0, exe.vms.length - 1))) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰒋"
    foreground: exe.lastError ? root.urgent : barForeground
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) exe.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dy) }
      onActivateRequested: root.activate()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        var key = text.toLowerCase()
        var vm = root.selectedVm()
        if (key === "o") exe.needsAuth ? exe.openSignIn() : exe.openHttps(vm)
        else if (key === "r" && vm) exe.restartVm(vm)
        else if (key === "c" && vm) exe.copySshDestination(vm)
        else if (key === "n" && !exe.needsAuth) exe.createVm()
        else if (key === "f") exe.refresh()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "exe.dev"
            meta: exe.refreshing ? "Refreshing…" : (exe.needsAuth ? "Connect your account" : (exe.vms.length + (exe.vms.length === 1 ? " VM" : " VMs")))
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰒋"
                color: exe.lastError ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            visible: exe.lastError !== ""
            width: parent.width
            text: exe.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Text {
            visible: exe.actionStatus !== ""
            width: parent.width
            text: exe.actionStatus
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          AuthRow {
            visible: exe.needsAuth
            width: parent.width
          }

          Text {
            visible: !exe.refreshing && !exe.needsAuth && exe.lastError === "" && exe.vms.length === 0
            width: parent.width
            text: "No VMs yet. Press N to create one."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Column {
            id: vmColumn
            visible: !exe.needsAuth
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: exe.vms
              delegate: VmRow { width: vmColumn.width; vm: modelData; rowIndex: index }
            }
          }

          Text {
            width: parent.width
            text: exe.needsAuth ? "↵ connect   O passkey sign-in   F retry" : "↵ SSH   O open   R restart   C copy   N new   F refresh"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component AuthRow: CursorSurface {
    hasCursor: root.cursorActive
    foreground: root.foreground
    implicitHeight: authLabels.implicitHeight + Style.space(18)

    Column {
      id: authLabels
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(10)
      spacing: Style.space(2)

      Text { text: "Connect exe.dev"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
      Text { width: parent.width; text: "Authorize once in a terminal. The panel stores a scoped 90-day API token in your keyring."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.cursorActive = true
      onClicked: root.activate()
    }
  }

  component VmRow: CursorSurface {
    id: row
    required property var vm
    required property int rowIndex
    hasCursor: root.cursorActive && root.vmIndex === rowIndex
    foreground: root.foreground
    implicitHeight: labels.implicitHeight + Style.space(14)

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: row.vm.status === "running" ? "●" : "○"
        color: row.vm.status === "running" ? root.foreground : root.dim
        font.pixelSize: Style.font.body
      }

      ColumnLayout {
        id: labels
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text { Layout.fillWidth: true; text: row.vm.vm_name; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight }
        Text { Layout.fillWidth: true; text: [row.vm.status, row.vm.region_display, row.vm.ssh_dest].filter(function(value) { return value !== "" }).join("  ·  "); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(row.rowIndex)
      onClicked: { root.setCursor(row.rowIndex); root.activate() }
    }
  }
}
