import AppKit
import ApplicationServices

enum AccessibilityPermission {
  static var isGranted: Bool {
    AXIsProcessTrusted()
  }

  static func requireBeforeLaunch() -> Bool {
    if isGranted {
      return true
    }

    while !isGranted {
      let (alert, launchAtLoginCheckbox) = permissionAlert()
      let response = alert.runModal()

      do {
        try LaunchAtLogin.setEnabled(launchAtLoginCheckbox.state == .on)
      } catch {
        NSLog("Unable to update launch at login: \(error)")
      }

      switch response {
      case .alertFirstButtonReturn:
        openSettings()
      case .alertSecondButtonReturn:
        continue
      default:
        return false
      }
    }

    return true
  }

  private static func permissionAlert() -> (NSAlert, NSButton) {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "MicGate needs Accessibility access to receive the microphone hotkey even when another app captures the keyboard."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open Settings")
    alert.addButton(withTitle: "Check Again")
    alert.addButton(withTitle: "Quit")

    let launchAtLoginCheckbox = NSButton(
      checkboxWithTitle: "Launch at Login",
      target: nil,
      action: nil,
    )
    launchAtLoginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
    alert.accessoryView = launchAtLoginCheckbox

    return (alert, launchAtLoginCheckbox)
  }

  private static func openSettings() {
    let urls = [
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
      "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
    ]

    for value in urls {
      guard let url = URL(string: value), NSWorkspace.shared.open(url) else {
        continue
      }
      return
    }
  }
}
