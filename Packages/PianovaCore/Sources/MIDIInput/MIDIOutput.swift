import CoreMIDI
import Foundation
import ScoreModel

/// Sends notes back to the connected instrument, so it makes the sound.
///
/// The closest thing to the player's own piano is the player's own piano. The
/// P-145 exposes a destination endpoint as well as a source, so the app can
/// hand notes back and let the instrument's own engine sound them — identical
/// response, identical timbre, nothing to download.
///
/// It also removes an echo nobody asked for: with the instrument connected and
/// the app synthesising too, pressing one key sounds twice, slightly apart.
public final class MIDIOutput: @unchecked Sendable {
  private var client = MIDIClientRef()
  private var port = MIDIPortRef()
  private var destination = MIDIEndpointRef()

  /// Whether a destination was found and opened.
  public private(set) var isConnected = false

  /// Creates an unopened output.
  public init() {}

  /// Names of every destination Core MIDI can see.
  public var destinationNames: [String] {
    (0..<MIDIGetNumberOfDestinations())
      .compactMap { index in
        Self.name(of: MIDIGetDestination(index))
      }
  }

  /// Opens the first destination that looks like the instrument.
  ///
  /// Matched by name or by being the only destination there is. Never by model
  /// number: the USB descriptor says `Digital Piano`, not `P-145`.
  /// - Returns: Whether a destination was opened.
  @discardableResult
  public func start() -> Bool {
    stop()

    guard MIDIClientCreate("Pianova Out" as CFString, nil, nil, &client) == noErr,
      MIDIOutputPortCreate(client, "Pianova Out Port" as CFString, &port) == noErr
    else {
      return false
    }

    let count = MIDIGetNumberOfDestinations()
    guard count > 0 else { return false }

    for index in 0..<count {
      let candidate = MIDIGetDestination(index)
      guard let name = Self.name(of: candidate) else { continue }

      if name.localizedCaseInsensitiveContains("piano") || count == 1 {
        destination = candidate
        isConnected = true
        return true
      }
    }

    return false
  }

  /// Closes the port.
  public func stop() {
    allNotesOff()
    if client != 0 { MIDIClientDispose(client) }
    client = MIDIClientRef()
    port = MIDIPortRef()
    destination = MIDIEndpointRef()
    isConnected = false
  }

  /// Starts a note on the instrument.
  /// - Parameters:
  ///   - pitch: The key to sound.
  ///   - velocity: How hard, 1 to 127.
  public func noteOn(_ pitch: Pitch, velocity: UInt8 = 80) {
    send([0x90, pitch.midiNoteNumber, max(velocity, 1)])
  }

  /// Stops a note on the instrument.
  /// - Parameter pitch: The key to release.
  public func noteOff(_ pitch: Pitch) {
    send([0x80, pitch.midiNoteNumber, 0])
  }

  /// Silences everything, on every channel.
  ///
  /// Sent on the way out and whenever routing is turned off, so a note cannot
  /// be left ringing on an instrument the app has stopped talking to.
  public func allNotesOff() {
    guard isConnected else { return }
    for channel in UInt8(0)..<16 {
      send([0xB0 | channel, 123, 0])
    }
  }

  private func send(_ bytes: [UInt8]) {
    guard isConnected, destination != 0 else { return }

    var packetList = MIDIPacketList()
    let packet = MIDIPacketListInit(&packetList)
    _ = MIDIPacketListAdd(&packetList, 1024, packet, 0, bytes.count, bytes)

    MIDISend(port, destination, &packetList)
  }

  private static func name(of endpoint: MIDIEndpointRef) -> String? {
    var value: Unmanaged<CFString>?
    guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value) == noErr,
      let name = value?.takeRetainedValue()
    else {
      return nil
    }
    return name as String
  }
}
