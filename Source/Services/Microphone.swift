import Foundation

enum Microphone {
  static func inputVolume() -> UInt8? {
    guard let output = runOSA(script: "input volume of (get volume settings)") else {
      return nil
    }
    return UInt8(output.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  static func setInputVolume(_ volume: UInt8) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", "set volume input volume \(volume)"]

    let errorPipe = Pipe()
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
      let message = String(data: data, encoding: .utf8) ?? "unknown osascript error"
      throw MicrophoneError(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
  }

  private static func runOSA(script: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return nil
    }

    guard process.terminationStatus == 0 else {
      return nil
    }

    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)
  }
}

private struct MicrophoneError: LocalizedError {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? {
    message
  }
}
