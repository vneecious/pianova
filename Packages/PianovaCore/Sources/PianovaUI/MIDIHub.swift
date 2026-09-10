import MIDIInput
import ScoreModel
import SwiftUI

/// Owns the connection to the instrument for the whole app.
///
/// One connection, opened once, handed to whichever screen is listening. Each
/// screen opening its own would fight over the same device.
@MainActor
public final class MIDIHub: ObservableObject {
  /// Set when the instrument could not be reached.
  @Published public private(set) var connectionError: String?

  /// Names of the connected instruments, for display.
  @Published public private(set) var sourceNames: [String] = []

  private let source: MIDIEventSource
  private var listener: ((MIDIKeyEvent) -> Void)?

  /// Who installed the current listener.
  ///
  /// SwiftUI builds the incoming screen before tearing down the outgoing one,
  /// so an unconditional clear on disappear would wipe the listener the new
  /// screen has already installed. Clearing is therefore scoped to its owner.
  private var listenerOwner: ObjectIdentifier?

  /// Creates a hub over a source.
  /// - Parameter source: Where key events come from.
  public init(source: MIDIEventSource) {
    self.source = source
  }

  /// Whether an instrument is answering.
  public var isConnected: Bool { connectionError == nil }

  /// Opens the connection.
  ///
  /// Safe to call again to retry after plugging the instrument in.
  /// Re-reads what is connected, without tearing the stream down.
  ///
  /// Called from the Core MIDI notification, so the header and the sound
  /// routing catch up on their own.
  public func refreshSources() {
    guard let coreMIDI = source as? CoreMIDIEventSource else { return }

    sourceNames = coreMIDI.sourceNames
    connectionError = sourceNames.isEmpty ? "Nenhum instrumento conectado" : nil
    onInstrumentChanged?()
  }

  /// Called when the set of connected instruments changes.
  public var onInstrumentChanged: (() -> Void)?

  /// Opens the instrument stream, replacing any already open.
  public func start() {
    source.stop()

    do {
      try source.start { [weak self] event in
        Task { @MainActor in
          self?.listener?(event)
        }
      }
      if let coreMIDI = source as? CoreMIDIEventSource {
        sourceNames = coreMIDI.sourceNames

        // Core MIDI tells us when instruments come and go. Without this the app
        // enumerates once at launch and never notices a piano plugged in after,
        // which reads as "it stopped recognising my piano".
        coreMIDI.onSetupChanged = { [weak self] in
          Task { @MainActor in self?.refreshSources() }
        }
      }
      connectionError = nil
    } catch MIDIInputError.noSourcesAvailable {
      sourceNames = []
      connectionError = "Nenhum instrumento conectado"
    } catch {
      sourceNames = []
      connectionError = "Não foi possível abrir o MIDI: \(error)"
    }
  }

  /// Routes incoming events to one screen at a time.
  /// - Parameters:
  ///   - owner: The object the listener belongs to.
  ///   - listener: Called for each event.
  public func setListener(owner: AnyObject, _ listener: @escaping (MIDIKeyEvent) -> Void) {
    listenerOwner = ObjectIdentifier(owner)
    self.listener = listener
  }

  /// Stops routing, but only if this owner still holds the listener.
  /// - Parameter owner: The object that installed it.
  public func clearListener(owner: AnyObject) {
    guard listenerOwner == ObjectIdentifier(owner) else { return }
    listenerOwner = nil
    listener = nil
  }
}
