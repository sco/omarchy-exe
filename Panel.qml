import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "sco.exe"
  ipcTarget: "sco.exe"

  property int vmIndex: 0
  property int actionIndex: 0
  property bool cursorActive: false
  property bool creating: false
  property string focusSection: "vms"
  property int headerIndex: 0
  readonly property var tabs: ["integrations", "lobby", "account"]
  readonly property color foreground: Color.popups.text
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int runningVmCount: exe.vms.filter(function(vm) { return vm.status === "running" }).length

  function selectedVm() {
    return exe.vms.length ? exe.vms[Math.max(0, Math.min(vmIndex, exe.vms.length - 1))] : null
  }

  function moveCursor(dy) {
    cursorActive = true
    if (focusSection === "header") {
      if (dy > 0) {
        focusSection = "vms"
        vmIndex = 0
        actionIndex = 0
      }
      return
    }
    if (!exe.needsAuth && exe.vms.length) {
      if (dy !== 0) {
        if (dy < 0 && vmIndex === 0) {
          focusSection = "header"
          headerIndex = 0
          actionIndex = 0
          return
        }
        vmIndex = Math.max(0, Math.min(exe.vms.length - 1, vmIndex + dy))
        actionIndex = 0
      }
    }
    scrollCursorIntoView()
  }

  function moveActionCursor(dx) {
    if (focusSection === "header") {
      headerIndex = Math.max(0, Math.min(tabs.length - 1, headerIndex + dx))
      return
    }
    if (exe.needsAuth || !exe.vms.length || dx === 0) return
    cursorActive = true
    var actions = vmActions(selectedVm())
    actionIndex = Math.max(0, Math.min(actions.length - 1, actionIndex + dx))
  }

  function vmActions(vm) {
    var actions = ["ssh"]
    if (vm && vm.https_url) actions.push("browser")
    if (vm && vm.shelley_url) actions.push("shelley")
    return actions
  }

  function actionPosition(vm, kind) {
    return vmActions(vm).indexOf(kind)
  }

  function vmSubtitle(vm, index) {
    if (!vm) return ""
    if (root.vmIndex === index) {
      var actions = vmActions(vm)
      var action = root.actionIndex < actions.length ? actions[root.actionIndex] : ""
      if (action === "ssh") return vm.ssh_dest ? ("$ ssh " + vm.ssh_dest) : "SSH unavailable"
      if (action === "browser") return "$ xdg-open " + vm.https_url
      if (action === "shelley") return "$ xdg-open " + vm.shelley_url
    }
    return vm.ssh_dest ? ("$ ssh " + vm.ssh_dest) : [vm.status, vm.region_display].filter(function(value) { return value !== "" }).join("  ·  ")
  }

  function setCursor(index, action) {
    cursorActive = true
    focusSection = "vms"
    vmIndex = index
    actionIndex = action === undefined ? 0 : action
    scrollCursorIntoView()
  }

  function activate() {
    if (focusSection === "header") {
      activateHeader(tabs[headerIndex])
      return
    }
    if (exe.needsAuth) {
      exe.openSetup()
      close()
      return
    }
    var vm = selectedVm()
    if (vm) {
      var actions = vmActions(vm)
      var action = actionIndex < actions.length ? actions[actionIndex] : "ssh"
      if (action === "browser") exe.openHttps(vm)
      else if (action === "shelley") exe.openShelley(vm)
      else exe.openTerminal(vm)
      close()
    }
  }

  function activateHeader(tab) {
    if (tab === "integrations") Qt.openUrlExternally("https://exe.dev/integrations")
    else if (tab === "lobby") exe.openLobby()
    else if (tab === "account") Qt.openUrlExternally("https://exe.dev/user")
    close()
  }

  function beginCreate() {
    creating = true
    nameField.text = ""
    promptField.text = ""
    Qt.callLater(function() { nameField.forceActiveFocus() })
  }

  function cancelCreate() {
    creating = false
    keys.forceActiveFocus()
  }

  function submitCreate() {
    exe.createVm(nameField.text, promptField.text)
    creating = false
    keys.forceActiveFocus()
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
    focusSection = "vms"
    headerIndex = 0
    actionIndex = 0
    creating = false
    panelFlick.contentY = 0
    exe.refresh()
  }

  Service {
    id: exe
    refreshIntervalSec: root.setting("refreshIntervalSec", 30)
    tokenLifetimeDays: root.setting("tokenLifetimeDays", 90)
  }

  Connections {
    target: exe
    function onVmsChanged() { root.vmIndex = Math.max(0, Math.min(root.vmIndex, Math.max(0, exe.vms.length - 1))) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Image {
        anchors.fill: parent
        source: "logo.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
      }
    }
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
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: root.creating && (nameField.activeFocus || promptField.activeFocus)
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
        else root.moveActionCursor(dx)
      }
      onActivateRequested: root.activate()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (root.focusSection !== "vms") return
        var key = text.toLowerCase()
        var vm = root.selectedVm()
        if (key === "o") exe.needsAuth ? exe.openSignIn() : exe.openHttps(vm)
        else if (key === "r" && vm) exe.restartVm(vm)
        else if (key === "c" && vm) exe.copySshDestination(vm)
        else if (key === "n" && !exe.needsAuth) root.beginCreate()
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
          spacing: Style.space(8)

          Item {
            width: parent.width
            implicitHeight: Math.max(headerFish.height, headerTitle.implicitHeight, headerTabs.implicitHeight)

            Image {
              id: headerFish
              width: Style.space(38)
              height: Style.space(38)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              source: "logo.png"
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
            }

            Text {
              id: headerTitle
              anchors.left: headerFish.right
              anchors.leftMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              text: "exe.dev"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Row {
              id: headerTabs
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              HeaderTab { tabIndex: 0; tab: "integrations"; svgPath: "M20.69,11.71a.78.78,0,0,0-.16-.24l-4-4a.75.75,0,1,0-1.06,1.06l2.72,2.72H5.81L8.53,8.53A.75.75,0,0,0,7.47,7.47l-4,4a.78.78,0,0,0-.16.24.73.73,0,0,0,0,.58.78.78,0,0,0,.16.24l4,4a.75.75,0,0,0,1.06,0,.75.75,0,0,0,0-1.06L5.81,12.75H18.19l-2.72,2.72a.75.75,0,0,0,0,1.06.75.75,0,0,0,1.06,0l4-4a.78.78,0,0,0,.16-.24A.73.73,0,0,0,20.69,11.71Z"; tooltipText: "Integrations" }
              HeaderTab { tabIndex: 1; tab: "lobby"; svgPath: "M10,17.75a.74.74,0,0,1-.53-.22.75.75,0,0,1,0-1.06L13.94,12,9.47,7.53a.75.75,0,0,1,1.06-1.06l5,5a.75.75,0,0,1,0,1.06l-5,5A.74.74,0,0,1,10,17.75Z"; tooltipText: "Open SSH lobby" }
              HeaderTab { tabIndex: 2; tab: "account"; svgPath: "M12,12.25A3.75,3.75,0,1,1,15.75,8.5,3.75,3.75,0,0,1,12,12.25Zm0-6A2.25,2.25,0,1,0,14.25,8.5,2.25,2.25,0,0,0,12,6.25ZM19,19.25a.76.76,0,0,1-.75-.75c0-1.95-1.06-3.25-6.25-3.25s-6.25,1.3-6.25,3.25a.75.75,0,0,1-1.5,0c0-4.75,5.43-4.75,7.75-4.75s7.75,0,7.75,4.75A.76.76,0,0,1,19,19.25Z"; tooltipText: "Account"; label: exe.username }
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

          Column {
            visible: root.creating
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "$ exe new"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            TextField {
              id: nameField
              width: parent.width
              placeholderText: "vm name (optional)"
              foreground: root.foreground
              font.family: root.fontFamily
              background: BorderSurface {
                color: Style.controlFill(nameField._focused, nameField._hot, nameField.foreground, nameField.accent)
                borderSpec: nameField._borderSpec
                radius: 0
              }
              onAccepted: promptField.forceActiveFocus()
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.cancelCreate()
                  event.accepted = true
                }
              }
            }

            TextField {
              id: promptField
              width: parent.width
              placeholderText: "prompt Shelley, then press Enter"
              foreground: root.foreground
              font.family: root.fontFamily
              background: BorderSurface {
                color: Style.controlFill(promptField._focused, promptField._hot, promptField.foreground, promptField.accent)
                borderSpec: promptField._borderSpec
                radius: 0
              }
              onAccepted: root.submitCreate()
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.cancelCreate()
                  event.accepted = true
                }
              }
            }
          }

          PanelSeparator {
            visible: !exe.needsAuth
            foreground: root.foreground
          }

          Column {
            visible: !exe.needsAuth
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "VMS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: !exe.refreshing && exe.lastError === "" && exe.vms.length === 0
              width: parent.width
              text: "No VMs yet. Press N to create one."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            Column {
              id: vmColumn
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: exe.vms
                delegate: VmRow { width: vmColumn.width }
              }
            }
          }

        }
      }
    }
  }

  component HeaderTab: BorderSurface {
    id: tabButton
    required property string tab
    required property int tabIndex
    required property string svgPath
    required property string tooltipText
    property string label: ""
    readonly property bool selected: root.cursorActive && root.focusSection === "header" && root.headerIndex === tabIndex

    implicitWidth: label === "" ? Style.space(28) : tabIcon.width + tabLabel.implicitWidth + Style.space(16)
    implicitHeight: Style.space(28)
    radius: 0
    color: selected ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10) : (tabMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06) : "transparent")
    borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, selected ? 0.34 : 0.22), 1)

    Image {
      id: tabIcon
      anchors.left: tabButton.label === "" ? undefined : parent.left
      anchors.leftMargin: tabButton.label === "" ? 0 : Style.space(6)
      anchors.horizontalCenter: tabButton.label === "" ? parent.horizontalCenter : undefined
      anchors.verticalCenter: parent.verticalCenter
      width: Style.font.icon
      height: width
      source: "data:image/svg+xml;utf8," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='" + String(tabButton.selected ? root.foreground : root.dim) + "'><path d='" + tabButton.svgPath + "'/></svg>")
      sourceSize.width: width
      sourceSize.height: height
      fillMode: Image.PreserveAspectFit
      smooth: true
      layer.enabled: true
      layer.effect: MultiEffect {
        brightness: 1
        colorization: 1
        colorizationColor: tabButton.selected ? root.foreground : root.dim
      }
    }

    Text {
      id: tabLabel
      visible: tabButton.label !== ""
      anchors.left: tabIcon.right
      anchors.leftMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      text: tabButton.label
      color: tabButton.selected ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: tabMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.focusSection = "header"
        root.headerIndex = tabButton.tabIndex
      }
      onClicked: root.activateHeader(tabButton.tab)
    }

    PanelToolTip {
      visible: tabMouse.containsMouse
      text: tabButton.tooltipText
      fontFamily: root.fontFamily
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
    required property var modelData
    required property int index
    readonly property var vm: modelData
    hasCursor: root.cursorActive && root.focusSection === "vms" && root.vmIndex === index && root.actionIndex === 0
    foreground: root.foreground
    implicitHeight: Style.space(44)
    radius: 0

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(row.index)
      onClicked: { root.setCursor(row.index); root.activate() }
    }

    Column {
      anchors.left: parent.left
      anchors.right: actions.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: (row.vm.emoji || (row.vm.status === "running" ? "●" : "○")) + "  " + row.vm.vm_name
        color: row.vm.status === "running" ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: root.vmSubtitle(row.vm, row.index)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Row {
      id: actions
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      PanelActionButton {
        visible: row.vm.ssh_dest !== ""
        iconText: "󰆍"
        tooltipText: "Open SSH session"
        foreground: root.foreground
        fontFamily: root.fontFamily
        radius: 0
        hasCursor: root.cursorActive && root.focusSection === "vms" && root.vmIndex === row.index && root.actionIndex === root.actionPosition(row.vm, "ssh")
        onHovered: function(isHovered) { if (isHovered) root.setCursor(row.index, root.actionPosition(row.vm, "ssh")) }
        onClicked: { exe.openTerminal(row.vm); root.close() }
      }

      PanelActionButton {
        visible: row.vm.https_url !== ""
        iconText: "󰖟"
        tooltipText: "Open in browser"
        foreground: root.foreground
        fontFamily: root.fontFamily
        radius: 0
        hasCursor: root.cursorActive && root.focusSection === "vms" && root.vmIndex === row.index && root.actionIndex === root.actionPosition(row.vm, "browser")
        onHovered: function(isHovered) { if (isHovered) root.setCursor(row.index, root.actionPosition(row.vm, "browser")) }
        onClicked: { exe.openHttps(row.vm); root.close() }
      }

      PanelActionButton {
        visible: row.vm.shelley_url !== ""
        iconText: "󰚩"
        tooltipText: "Open Shelley"
        foreground: root.foreground
        fontFamily: root.fontFamily
        radius: 0
        hasCursor: root.cursorActive && root.focusSection === "vms" && root.vmIndex === row.index && root.actionIndex === root.actionPosition(row.vm, "shelley")
        onHovered: function(isHovered) { if (isHovered) root.setCursor(row.index, root.actionPosition(row.vm, "shelley")) }
        onClicked: { exe.openShelley(row.vm); root.close() }
      }
    }
  }
}
