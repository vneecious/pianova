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

    // A block, not `nil`: with no notification callback the app enumerates
    // devices once at launch and never learns anything again. Plug the piano in
    // after opening the app and it would simply never be noticed.
    let clientStatus = MIDIClientCreateWithBlock("Pianova" as CFString, &client) {
      [weak self] notification in
      guard notification.pointee.messageID == .msgSetupChanged else { return }
      self?.connectEverySource()
    }
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

    connectEverySource()

    guard MIDIGetNumberOfSources() > 0 else {
      throw MIDIInputError.noSourcesAvailable
    }
  }

  /// Connects the port to every source Core MIDI can currently see.
  ///
  /// Run again whenever the setup changes, so an instrument connected after the
  /// app opened is picked up without anyone pressing anything. Connecting a
  /// source twice is harmless.
  private func connectEverySource() {
    guard port != 0 else { return }

    for index in 0..<MIDIGetNumberOfSources() {
      MIDIPortConnectSource(port, MIDIGetSource(index), nil)
    }

    // Read the stored handler, never the public accessor: the accessor takes
    // the same lock, and `NSLock` is not reentrant — locking twice on one
    // thread deadlocks, which froze the app before it drew a single window.
    lock.lock()
    let notify = setupHandler
    lock.unlock()

    notify?()
  }

  /// Called when instruments appear or disappear, so the screen can catch up.
  public var onSetupChanged: (@Sendable () -> Void)? {
    get { lock.withLock { setupHandler } }
    set { lock.withLock { setupHandler = newValue } }
  }

  private var setupHandler: (@Sendable () -> Void)?

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
