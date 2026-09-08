import CoreMIDI
import Foundation

/// A ``MIDIEventSource`` backed by Core MIDI.
///
/// Connects to every source it finds. The app targets a single known
/// instrument, so there is deliberately no device picking or filtering.
///
/// This type is the I/O shell around ``MIDIMessageParser``: it holds no
/// decoding logic of its own, which is what keeps the decoding testable
/// without hardware.
public final class CoreMIDIEventSource: MIDIEventSource, @unchecked Sendable {
  private let lock = NSLock()
  private var parser = MIDIMessageParser()
  private var handler: (@Sendable (MIDIKeyEvent) -> Void)?
  private var client = MIDIClientRef()
  private var port = MIDIPortRef()

  /// Creates a source that is not yet listening.
  public init() {}

  /// Opens a Core MIDI client and connects to every available source.
  /// - Parameter handler: Called for each decoded event, on a Core MIDI thread.
  /// - Throws: ``MIDIInputError`` if the client or port cannot be created, or
  ///   if no instrument is connected.
  public func start(handler: @escaping @Sendable (MIDIKeyEvent) -> Void) throws {
    lock.lock()
    self.handler = handler
    lock.unlock()

    let clientStatus = MIDIClientCreate("Pianova" as CFString, nil, nil, &client)
    guard clientStatus == noErr else {
      throw MIDIInputError.clientCreationFailed(clientStatus)
    }

    let portStatus = MIDIInputPortCreateWithBlock(client, "Pianova In" as CFString, &port) {
      [weak self] packetList, _ in
      self?.receive(packetList)
    }
    guard portStatus == noErr else {
      throw MIDIInputError.portCreationFailed(portStatus)
    }

    let sourceCount = MIDIGetNumberOfSources()
    guard sourceCount > 0 else {
      throw MIDIInputError.noSourcesAvailable
    }
    for index in 0..<sourceCount {
      MIDIPortConnectSource(port, MIDIGetSource(index), nil)
    }
  }

  /// Stops delivering events and disposes of the Core MIDI resources.
  public func stop() {
    lock.lock()
    handler = nil
    lock.unlock()

    if port != 0 {
      MIDIPortDispose(port)
      port = 0
    }
    if client != 0 {
      MIDIClientDispose(client)
      client = 0
    }
  }

  /// Names of the connected sources, for display.
  public var sourceNames: [String] {
    (0..<MIDIGetNumberOfSources())
      .map { index in
        let source = MIDIGetSource(index)
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(source, kMIDIPropertyName, &value) == noErr,
          let name = value?.takeRetainedValue()
        else { return "?" }
        return name as String
      }
  }

  private func receive(_ packetList: UnsafePointer<MIDIPacketList>) {
    var packet = packetList.pointee.packet

    for _ in 0..<packetList.pointee.numPackets {
      let length = Int(packet.length)
      var bytes: [UInt8] = []
      bytes.reserveCapacity(length)
      withUnsafeBytes(of: packet.data) { raw in
        for offset in 0..<min(length, raw.count) {
          bytes.append(raw[offset])
        }
      }

      lock.lock()
      let events = parser.parse(bytes)
      let currentHandler = handler
      lock.unlock()

      if let currentHandler {
        for event in events {
          currentHandler(event)
        }
      }

      packet = MIDIPacketNext(&packet).pointee
    }
  }
}
