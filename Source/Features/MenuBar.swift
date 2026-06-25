import AppKit

final class MenuBar {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let menu = NSMenu()
  private let currentHotKeyItem = NSMenuItem(title: "Current: Option + /", action: nil, keyEquivalent: "")

  var isRightClick: Bool {
    guard let event = NSApp.currentEvent else {
      return false
    }
    return event.type == .rightMouseDown || event.buttonNumber == 1
  }

  func configure(delegate: AnyObject) {
    guard let button = statusItem.button else {
      return
    }

    button.target = delegate
    button.action = #selector(AppController.statusItemClicked(_:))
    button.sendAction(on: [.leftMouseDown, .rightMouseDown])

    currentHotKeyItem.isEnabled = false
    menu.addItem(currentHotKeyItem)

    let setHotKeyItem = NSMenuItem(
      title: "Set Hotkey...",
      action: #selector(AppController.setHotKey(_:)),
      keyEquivalent: "",
    )
    setHotKeyItem.target = delegate
    menu.addItem(setHotKeyItem)

    let resetHotKeyItem = NSMenuItem(
      title: "Reset to Default",
      action: #selector(AppController.resetHotKey(_:)),
      keyEquivalent: "",
    )
    resetHotKeyItem.target = delegate
    menu.addItem(resetHotKeyItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit",
      action: #selector(AppController.quit(_:)),
      keyEquivalent: "",
    )
    quitItem.target = delegate
    menu.addItem(quitItem)
  }

  func updateMicrophoneState(micOn: Bool, hotKey: HotKey) {
    guard let button = statusItem.button else {
      return
    }

    let symbolName = micOn ? "mic" : "mic.slash"
    let tooltip = micOn
      ? "Microphone is on. Click or press \(hotKey.label) to mute."
      : "Microphone is muted. Click or press \(hotKey.label) to unmute."

    if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip) {
      image.isTemplate = true
      button.image = image
      button.title = ""
    }

    button.toolTip = tooltip
    button.appearsDisabled = false
  }

  func updateHotKey(_ hotKey: HotKey) {
    currentHotKeyItem.title = "Current: \(hotKey.label)"
  }

  func popup(hotKey: HotKey) {
    updateHotKey(hotKey)
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }
}
