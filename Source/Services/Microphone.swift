import CoreAudio
import Foundation

enum Microphone {
  static func inputVolume() -> UInt8? {
    guard let device = try? defaultInputDevice() else {
      return nil
    }

    if (try? isMuted(device: device)) == true {
      return 0
    }

    guard let volume = try? inputVolumeScalar(device: device) else {
      return nil
    }

    return UInt8((volume * 100).rounded())
  }

  static func setInputVolume(_ volume: UInt8) throws {
    let device = try defaultInputDevice()
    let clampedVolume = min(volume, 100)

    if clampedVolume == 0 {
      if try setMute(true, device: device) {
        return
      }

      try setInputVolumeScalar(0, device: device)
      return
    }

    let didSetMute = try setMute(false, device: device)
    let currentVolume = (try? inputVolumeScalar(device: device)) ?? 0

    if !didSetMute || currentVolume <= 0 {
      try setInputVolumeScalar(Float32(clampedVolume) / 100, device: device)
    }
  }

  private static func defaultInputDevice() throws -> AudioObjectID {
    var device = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain,
    )

    try check(
      AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size,
        &device,
      ),
      "Unable to read default input device",
    )

    guard device != kAudioObjectUnknown else {
      throw MicrophoneError("Default input device is unavailable")
    }

    return device
  }

  private static func isMuted(device: AudioObjectID) throws -> Bool {
    var muted = UInt32(0)
    var address = inputAddress(selector: kAudioDevicePropertyMute)
    var size = UInt32(MemoryLayout<UInt32>.size)

    try check(
      AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted),
      "Unable to read input mute",
    )

    return muted != 0
  }

  @discardableResult
  private static func setMute(_ muted: Bool, device: AudioObjectID) throws -> Bool {
    var address = inputAddress(selector: kAudioDevicePropertyMute)

    guard
      AudioObjectHasProperty(device, &address),
      (try? isPropertySettable(device: device, address: &address)) == true
    else {
      return false
    }

    var value = UInt32(muted ? 1 : 0)
    let size = UInt32(MemoryLayout<UInt32>.size)

    try check(
      AudioObjectSetPropertyData(device, &address, 0, nil, size, &value),
      "Unable to set input mute",
    )

    return true
  }

  private static func inputVolumeScalar(device: AudioObjectID) throws -> Float32 {
    if let masterVolume = try? readVolume(device: device, element: kAudioObjectPropertyElementMain) {
      return masterVolume
    }

    let channelVolumes = try inputChannelElements(device: device).compactMap {
      try? readVolume(device: device, element: $0)
    }

    guard !channelVolumes.isEmpty else {
      throw MicrophoneError("Input volume is unavailable")
    }

    return channelVolumes.reduce(0, +) / Float32(channelVolumes.count)
  }

  private static func setInputVolumeScalar(_ volume: Float32, device: AudioObjectID) throws {
    if try setVolume(volume, device: device, element: kAudioObjectPropertyElementMain) {
      return
    }

    let channelElements = try inputChannelElements(device: device)
    var didSetVolume = false

    for element in channelElements {
      didSetVolume = try setVolume(volume, device: device, element: element) || didSetVolume
    }

    if !didSetVolume {
      throw MicrophoneError("Input volume is not settable")
    }
  }

  private static func readVolume(device: AudioObjectID, element: AudioObjectPropertyElement) throws -> Float32 {
    var volume = Float32(0)
    var address = inputAddress(selector: kAudioDevicePropertyVolumeScalar, element: element)
    var size = UInt32(MemoryLayout<Float32>.size)

    try check(
      AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume),
      "Unable to read input volume",
    )

    return volume
  }

  @discardableResult
  private static func setVolume(
    _ volume: Float32,
    device: AudioObjectID,
    element: AudioObjectPropertyElement,
  ) throws -> Bool {
    var address = inputAddress(selector: kAudioDevicePropertyVolumeScalar, element: element)

    guard
      AudioObjectHasProperty(device, &address),
      (try? isPropertySettable(device: device, address: &address)) == true
    else {
      return false
    }

    var nextVolume = max(0, min(volume, 1))
    let size = UInt32(MemoryLayout<Float32>.size)

    try check(
      AudioObjectSetPropertyData(device, &address, 0, nil, size, &nextVolume),
      "Unable to set input volume",
    )

    return true
  }

  private static func inputChannelElements(device: AudioObjectID) throws -> [AudioObjectPropertyElement] {
    var address = inputAddress(selector: kAudioDevicePropertyStreamConfiguration)
    var size = UInt32(0)

    try check(
      AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size),
      "Unable to read input stream configuration size",
    )

    let rawBufferList = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size),
      alignment: MemoryLayout<AudioBufferList>.alignment,
    )
    let audioBufferList = rawBufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
    let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
    defer {
      rawBufferList.deallocate()
    }

    try check(
      AudioObjectGetPropertyData(device, &address, 0, nil, &size, bufferList.unsafeMutablePointer),
      "Unable to read input stream configuration",
    )

    let channelCount = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }

    guard channelCount > 0 else {
      throw MicrophoneError("Input device has no input channels")
    }

    return (1 ... channelCount).map(AudioObjectPropertyElement.init)
  }

  private static func isPropertySettable(
    device: AudioObjectID,
    address: inout AudioObjectPropertyAddress,
  ) throws -> Bool {
    var isSettable = DarwinBoolean(false)

    try check(
      AudioObjectIsPropertySettable(device, &address, &isSettable),
      "Unable to check audio property mutability",
    )

    return isSettable.boolValue
  }

  private static func inputAddress(
    selector: AudioObjectPropertySelector,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
  ) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioDevicePropertyScopeInput,
      mElement: element,
    )
  }

  private static func check(_ status: OSStatus, _ message: String) throws {
    guard status == noErr else {
      throw MicrophoneError("\(message): \(status)")
    }
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
