import Foundation

/// A stream of key events coming from an instrument.
///
/// The seam that keeps the exercise logic testable: production uses
/// ``CoreMIDIEventSource``, tests feed synthetic events instead.
public protocol MIDIEventSource: AnyObject {
  /// Starts delivering events.
  /// - Parameter handler: Called for each decoded event, on an arbitrary
  ///   thread. Do not assume the main thread.
  /// - Throws: ``MIDIInputError`` if the stream cannot be opened.
  func start(handler: @escaping @Sendable (MIDIKeyEvent) -> Void) throws

  /// Stops delivering events and releases the underlying resources.
  func stop()
}

/// Something that went wrong while opening a MIDI stream.
public enum MIDIInputError: Error, Equatable {
  /// The MIDI client could not be created.
  case clientCreationFailed(OSStatus)

  /// The input port could not be created.
  case portCreationFailed(OSStatus)

  /// Nothing is plugged in, so there is nothing to listen to.
  case noSourcesAvailable
}
