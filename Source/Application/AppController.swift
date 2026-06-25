import AppKit
import UserNotifications

final class AppController: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  static weak var shared: AppController?

  private let menuBar = MenuBar()
  private var hotKey = HotKey.default
  private var hotKeyRegistration: HotKeyRegistration?
  private var micOn = Microphone.inputVolume().map { $0 > 0 } ?? false
  private var notifying = false

  override init() {
    super.init()
    Self.shared = self
  }

  func applicationDidFinishLaunching(_: Notification) {
    guard AccessibilityPermission.requireBeforeLaunch() else {
      NSApp.terminate(nil)
      return
    }

    let center = UNUserNotificationCenter.current()
    center.delegate = self

    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      NSLog("Notifications granted: \(granted)")
      if let error {
        NSLog("Notification authorization error: \(error)")
      }
    }

    menuBar.configure(delegate: self)
    updateStatusItem()
    refreshHotKeyMenu()
    installHotKey(hotKey)
  }

  func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent _: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void,
  ) {
    completionHandler([.list, .banner, .sound])
  }

  @objc func statusItemClicked(_: Any?) {
    if menuBar.isRightClick {
      showMenu()
    } else {
      toggleMicrophone()
    }
  }

  @objc func setHotKey(_: Any?) {
    switch HotKeyPrompt.prompt(current: hotKey) {
    case .success(let next):
      changeHotKey(next)
    case .failure(let message):
      HotKeyPrompt.showInvalid(message)
    case .cancelled:
      break
    }
  }

  @objc func resetHotKey(_: Any?) {
    changeHotKey(.default)
  }

  @objc func quit(_: Any?) {
    NSApp.terminate(nil)
  }

  func toggleMicrophone() {
    if notifying {
      return
    }

    notifying = true
    defer {
      notifying = false
    }

    let nextOn = (Microphone.inputVolume() ?? 0) == 0
    let volume: UInt8 = nextOn ? 100 : 0

    do {
      try Microphone.setInputVolume(volume)
      micOn = nextOn
      updateStatusItem()
      Notifier.deliver(
        message: nextOn ? "ON" : "OFF",
        sound: nextOn ? "Funk" : "Bottle",
      )
    } catch {
      fputs("Unable to set input volume: \(error)\n", stderr)
    }
  }

  private func showMenu() {
    refreshHotKeyMenu()
    menuBar.popup(hotKey: hotKey)
  }

  private func updateStatusItem() {
    menuBar.updateMicrophoneState(micOn: micOn, hotKey: hotKey)
  }

  private func refreshHotKeyMenu() {
    menuBar.updateHotKey(hotKey)
  }

  private func changeHotKey(_ nextHotKey: HotKey) {
    if nextHotKey.keyCode == hotKey.keyCode, nextHotKey.modifiers == hotKey.modifiers {
      return
    }

    let previousHotKey = hotKey
    let previousRegistration = hotKeyRegistration
    hotKeyRegistration?.unregister()
    hotKeyRegistration = nil

    do {
      hotKeyRegistration = try HotKeyRegistration.register(nextHotKey)
      hotKey = nextHotKey
      refreshHotKeyMenu()
      updateStatusItem()
    } catch {
      hotKey = previousHotKey
      hotKeyRegistration = previousRegistration
      HotKeyPrompt.showInvalid("Unable to register \(nextHotKey.label).")
    }
  }

  private func installHotKey(_ hotKey: HotKey) {
    do {
      hotKeyRegistration = try HotKeyRegistration.register(hotKey)
    } catch {
      fputs("Unable to register \(hotKey.label): \(error)\n", stderr)
    }
  }
}
