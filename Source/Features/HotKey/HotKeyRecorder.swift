import AppKit
import ApplicationServices
import Carbon

enum HotKeyPromptResult {
  case success(HotKey)
  case failure(String)
  case cancelled
}

enum HotKeyPrompt {
  static func prompt(current: HotKey) -> HotKeyPromptResult {
    let alert = NSAlert()
    alert.messageText = "Microphone Hotkey"
    alert.informativeText = "Press a key combination to use as the microphone hotkey."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Set")
    alert.addButton(withTitle: "Cancel")

    let recorderView = HotKeyRecorderView(current: current)
    alert.accessoryView = recorderView
    alert.buttons.first?.isEnabled = false

    let recorder = HotKeyRecorder { event in
      switch recorderView.record(event: event) {
      case .recorded:
        alert.buttons.first?.isEnabled = true

      case .ignored:
        break

      case .cancel:
        alert.window.orderOut(nil)
        NSApp.stopModal(withCode: .alertSecondButtonReturn)
      }
    }

    do {
      try recorder.start()
    } catch {
      return .failure(error.localizedDescription)
    }

    NSApp.activate(ignoringOtherApps: true)
    let response = alert.runModal()
    recorder.stop()

    if response != .alertFirstButtonReturn {
      return .cancelled
    }

    guard let hotKey = recorderView.hotKey else {
      return .failure("Press a key combination before saving.")
    }

    return .success(hotKey)
  }

  static func showInvalid(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Invalid hotkey"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
  }
}

private final class HotKeyRecorder {
  private let onEvent: (NSEvent) -> Void
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?

  init(onEvent: @escaping (NSEvent) -> Void) {
    self.onEvent = onEvent
  }

  deinit {
    stop()
  }

  func start() throws {
    let eventMask = [CGEventType.keyDown, .keyUp, .flagsChanged]
      .reduce(CGEventMask()) { mask, type in
        mask | CGEventMask(1 << type.rawValue)
      }

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: hotKeyRecorderCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque(),
      )
    else {
      throw HotKeyRecorderError.tapCreateFailed
    }

    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
      CFMachPortInvalidate(eventTap)
      throw HotKeyRecorderError.runLoopSourceCreateFailed
    }

    self.eventTap = eventTap
    self.runLoopSource = runLoopSource
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  func stop() {
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
      self.runLoopSource = nil
    }

    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
      self.eventTap = nil
    }
  }

  fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    switch type {
    case .keyDown,
         .flagsChanged:
      if let event = NSEvent(cgEvent: event) {
        onEvent(event)
      }
      return nil

    case .keyUp:
      return nil

    case .tapDisabledByTimeout,
         .tapDisabledByUserInput:
      if let eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return Unmanaged.passUnretained(event)

    default:
      return Unmanaged.passUnretained(event)
    }
  }
}

private func hotKeyRecorderCallback(
  _: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  refcon: UnsafeMutableRawPointer?,
) -> Unmanaged<CGEvent>? {
  guard let refcon else {
    return Unmanaged.passUnretained(event)
  }

  let recorder = Unmanaged<HotKeyRecorder>.fromOpaque(refcon).takeUnretainedValue()
  return recorder.handle(type: type, event: event)
}

private enum HotKeyRecorderError: LocalizedError {
  case tapCreateFailed
  case runLoopSourceCreateFailed

  var errorDescription: String? {
    switch self {
    case .tapCreateFailed:
      "Unable to start hotkey recording. Check Accessibility permission."
    case .runLoopSourceCreateFailed:
      "Unable to attach hotkey recording to the main run loop."
    }
  }
}

private final class HotKeyRecorderView: NSView {
  enum RecordResult {
    case recorded
    case ignored
    case cancel
  }

  private let titleLabel = NSTextField(labelWithString: "Press a shortcut")
  private let valueLabel = NSTextField(labelWithString: "")
  private let hintLabel = NSTextField(labelWithString: "Use at least one modifier. Escape cancels.")

  private(set) var hotKey: HotKey?

  init(current: HotKey) {
    super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 92))
    hotKey = current
    buildLayout(current: current)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    nil
  }

  func record(event: NSEvent) -> RecordResult {
    if event.type == .flagsChanged {
      updatePreview(modifiers: carbonModifiers(from: event.modifierFlags), key: nil)
      return .ignored
    }

    guard event.type == .keyDown else {
      return .ignored
    }
    if event.keyCode == UInt16(kVK_Escape) {
      return .cancel
    }
    if event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) {
      return .ignored
    }

    let modifiers = carbonModifiers(from: event.modifierFlags)
    do {
      let nextHotKey = try HotKey.make(
        keyCode: UInt32(event.keyCode),
        modifiers: modifiers,
      )
      hotKey = nextHotKey
      valueLabel.stringValue = nextHotKey.label
      valueLabel.textColor = .labelColor
      return .recorded
    } catch {
      valueLabel.stringValue = error.localizedDescription
      valueLabel.textColor = .systemRed
      return .ignored
    }
  }

  private func buildLayout(current: HotKey) {
    wantsLayer = true
    layer?.cornerRadius = 8
    layer?.borderWidth = 1
    layer?.borderColor = NSColor.separatorColor.cgColor
    layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

    titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
    valueLabel.font = .monospacedSystemFont(ofSize: 20, weight: .semibold)
    valueLabel.stringValue = current.label
    hintLabel.font = .systemFont(ofSize: 11)
    hintLabel.textColor = .secondaryLabelColor

    let stack = NSStackView(views: [titleLabel, valueLabel, hintLabel])
    stack.orientation = .vertical
    stack.alignment = .centerX
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false

    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }

  private func updatePreview(modifiers: UInt32, key: String?) {
    guard modifiers != 0 else {
      valueLabel.stringValue = hotKey?.label ?? ""
      valueLabel.textColor = .labelColor
      return
    }

    valueLabel.stringValue = HotKey.formatLabel(modifiers: modifiers, key: key ?? "...")
    valueLabel.textColor = .secondaryLabelColor
  }

  private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var modifiers: UInt32 = 0
    if flags.contains(.control) {
      modifiers |= UInt32(controlKey)
    }
    if flags.contains(.option) {
      modifiers |= UInt32(optionKey)
    }
    if flags.contains(.shift) {
      modifiers |= UInt32(shiftKey)
    }
    if flags.contains(.command) {
      modifiers |= UInt32(cmdKey)
    }
    return modifiers
  }
}
