import AppKit
import UserNotifications

enum Notifier {
  private static var activeSounds = [NSSound]()

  static func deliver(message: String, sound: String) {
    playSystemSound(sound)

    let center = UNUserNotificationCenter.current()

    let content = UNMutableNotificationContent()
    content.title = "Microphone"
    content.body = message
    content.sound = nil

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil,
    )

    center.add(request) { error in
      if let error {
        NSLog("Notification add error: \(error)")
        NSLog("NSError: \(error as NSError)")
      } else {
        NSLog("Notification delivered: \(message)")
      }
    }
  }

  static func playSystemSound(_ name: String) {
    guard let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else {
      print("Sound not found:", name)
      return
    }

    activeSounds.append(sound)
    sound.play()

    DispatchQueue.main.asyncAfter(deadline: .now() + sound.duration + 0.2) {
      activeSounds.removeAll { $0 === sound }
    }
  }
}
