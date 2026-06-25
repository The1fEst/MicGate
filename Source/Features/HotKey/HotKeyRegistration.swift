import AppKit
import ApplicationServices

final class HotKeyRegistration {
  private static var activeHotKey: HotKey?
  private static weak var activeRegistration: HotKeyRegistration?

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?

  private init(eventTap: CFMachPort, runLoopSource: CFRunLoopSource) {
    self.eventTap = eventTap
    self.runLoopSource = runLoopSource
  }

  deinit {
    unregister()
  }

  static func register(_ hotKey: HotKey) throws -> HotKeyRegistration {
    guard AccessibilityPermission.isGranted else {
      throw HotKeyEventTapError.notTrusted
    }

    let hidEventTap = CGEventTapLocation(rawValue: 0)!
    let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    guard
      let eventTap = CGEvent.tapCreate(
        tap: hidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: hotKeyEventTapCallback,
        userInfo: nil,
      )
    else {
      throw HotKeyEventTapError.tapCreateFailed
    }

    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
      CFMachPortInvalidate(eventTap)
      throw HotKeyEventTapError.runLoopSourceCreateFailed
    }

    CFRunLoopAddSource(
      CFRunLoopGetMain(),
      runLoopSource,
      .commonModes,
    )
    CGEvent.tapEnable(tap: eventTap, enable: true)

    let registration = HotKeyRegistration(eventTap: eventTap, runLoopSource: runLoopSource)
    activeHotKey = hotKey
    activeRegistration = registration

    return registration
  }

  func unregister() {
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
      self.runLoopSource = nil
    }

    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
      self.eventTap = nil
    }

    if Self.activeRegistration === self {
      Self.activeRegistration = nil
      Self.activeHotKey = nil
    }
  }

  fileprivate static func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    switch type {
    case .keyDown:
      guard let activeHotKey, activeHotKey.matches(event: event) else {
        return Unmanaged.passUnretained(event)
      }

      DispatchQueue.main.async {
        AppController.shared?.toggleMicrophone()
      }
      return nil

    case .tapDisabledByTimeout,
         .tapDisabledByUserInput:
      if let eventTap = activeRegistration?.eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return Unmanaged.passUnretained(event)

    default:
      return Unmanaged.passUnretained(event)
    }
  }
}

private func hotKeyEventTapCallback(
  _: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  refcon _: UnsafeMutableRawPointer?,
) -> Unmanaged<CGEvent>? {
  HotKeyRegistration.handle(type: type, event: event)
}

private enum HotKeyEventTapError: LocalizedError {
  case notTrusted
  case tapCreateFailed
  case runLoopSourceCreateFailed

  var errorDescription: String? {
    switch self {
    case .notTrusted:
      "MicGate needs Accessibility permission to listen for hotkeys while other apps capture the keyboard."
    case .tapCreateFailed:
      "Unable to create keyboard event tap."
    case .runLoopSourceCreateFailed:
      "Unable to attach keyboard event tap to the main run loop."
    }
  }
}
