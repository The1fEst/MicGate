import AppKit
import ApplicationServices
import Carbon

struct HotKey: Equatable {
  let label: String
  let keyCode: UInt32
  let modifiers: UInt32

  static let `default` = HotKey(
    label: "Option + /",
    keyCode: UInt32(kVK_ANSI_Slash),
    modifiers: UInt32(optionKey),
  )

  var eventFlags: CGEventFlags {
    var flags = CGEventFlags()
    if modifiers & UInt32(cmdKey) != 0 {
      flags.insert(.maskCommand)
    }
    if modifiers & UInt32(controlKey) != 0 {
      flags.insert(.maskControl)
    }
    if modifiers & UInt32(optionKey) != 0 {
      flags.insert(.maskAlternate)
    }
    if modifiers & UInt32(shiftKey) != 0 {
      flags.insert(.maskShift)
    }
    return flags
  }

  func matches(event: CGEvent) -> Bool {
    let eventKeyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
    guard eventKeyCode == keyCode else {
      return false
    }

    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    guard !isRepeat else {
      return false
    }

    return event.flags.intersection(Self.eventModifierMask) == eventFlags
  }

  private static let eventModifierMask: CGEventFlags = [
    .maskCommand,
    .maskControl,
    .maskAlternate,
    .maskShift,
  ]

  static func make(
    keyCode: UInt32,
    modifiers: UInt32,
  ) throws -> HotKey {
    guard modifiers != 0 else {
      throw HotKeyError("Hotkey must include Control, Option, Shift, or Command.")
    }
    guard let key = keyLabel(for: keyCode) else {
      throw HotKeyError("Unsupported key.")
    }

    return HotKey(
      label: Self.formatLabel(modifiers: modifiers, key: key),
      keyCode: keyCode,
      modifiers: modifiers,
    )
  }

  static func formatLabel(modifiers: UInt32, key: String) -> String {
    var parts = [String]()
    if modifiers & UInt32(controlKey) != 0 {
      parts.append("Control")
    }
    if modifiers & UInt32(optionKey) != 0 {
      parts.append("Option")
    }
    if modifiers & UInt32(shiftKey) != 0 {
      parts.append("Shift")
    }
    if modifiers & UInt32(cmdKey) != 0 {
      parts.append("Command")
    }
    parts.append(key)
    return parts.joined(separator: " + ")
  }

  private static func keyLabel(for keyCode: UInt32) -> String? {
    keyLabelsByCode[keyCode]
  }

  private static let keyLabelsByCode: [UInt32: String] = [
    UInt32(kVK_ANSI_A): "A",
    UInt32(kVK_ANSI_S): "S",
    UInt32(kVK_ANSI_D): "D",
    UInt32(kVK_ANSI_F): "F",
    UInt32(kVK_ANSI_H): "H",
    UInt32(kVK_ANSI_G): "G",
    UInt32(kVK_ANSI_Z): "Z",
    UInt32(kVK_ANSI_X): "X",
    UInt32(kVK_ANSI_C): "C",
    UInt32(kVK_ANSI_V): "V",
    UInt32(kVK_ANSI_B): "B",
    UInt32(kVK_ANSI_Q): "Q",
    UInt32(kVK_ANSI_W): "W",
    UInt32(kVK_ANSI_E): "E",
    UInt32(kVK_ANSI_R): "R",
    UInt32(kVK_ANSI_Y): "Y",
    UInt32(kVK_ANSI_T): "T",
    UInt32(kVK_ANSI_1): "1",
    UInt32(kVK_ANSI_2): "2",
    UInt32(kVK_ANSI_3): "3",
    UInt32(kVK_ANSI_4): "4",
    UInt32(kVK_ANSI_6): "6",
    UInt32(kVK_ANSI_5): "5",
    UInt32(kVK_ANSI_Equal): "=",
    UInt32(kVK_ANSI_9): "9",
    UInt32(kVK_ANSI_7): "7",
    UInt32(kVK_ANSI_Minus): "-",
    UInt32(kVK_ANSI_8): "8",
    UInt32(kVK_ANSI_0): "0",
    UInt32(kVK_ANSI_RightBracket): "]",
    UInt32(kVK_ANSI_O): "O",
    UInt32(kVK_ANSI_U): "U",
    UInt32(kVK_ANSI_LeftBracket): "[",
    UInt32(kVK_ANSI_I): "I",
    UInt32(kVK_ANSI_P): "P",
    UInt32(kVK_ANSI_L): "L",
    UInt32(kVK_ANSI_J): "J",
    UInt32(kVK_ANSI_Quote): "'",
    UInt32(kVK_ANSI_K): "K",
    UInt32(kVK_ANSI_Semicolon): ";",
    UInt32(kVK_ANSI_Backslash): "\\",
    UInt32(kVK_ANSI_Comma): ",",
    UInt32(kVK_ANSI_Slash): "/",
    UInt32(kVK_ANSI_N): "N",
    UInt32(kVK_ANSI_M): "M",
    UInt32(kVK_ANSI_Period): ".",
    UInt32(kVK_ANSI_Grave): "`",
  ]
}

struct HotKeyError: LocalizedError {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? {
    message
  }
}
