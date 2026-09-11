import Engraving
import ExerciseEngine
import Foundation
import ScoreModel

/// Runs a piece that a real engraver drew.
///
/// The engraver decides nothing: it hands over pages and a list of moments,
/// each carrying the identifiers it drew and the keys they stand for. Judging
/// stays here, with the same rules as everywhere else — right note advances,
/// wrong note steps back.
@MainActor
public final class EngravedPlayController: ObservableObject {
  /// The pages, in order.
  @Published public private(set) var pages: [EngravedPage] = []

  /// How each identifier should read right now.
  @Published public private(set) var highlights: [String: ItemState] = [:]

  /// The identifier the cursor is on, for scrolling to it.
  @Published public private(set) var focus: String?

  /// Why the piece could not be engraved, if it could not.
  @Published public private(set) var failure: String?

  private var events: [EngravedEvent] = []
  private var session: ExerciseSession?

  /// Called once the whole piece has been played.
  public var onFinished: () -> Void = {}

  /// Creates an empty controller, ready to be handed a piece.
  public init() {}

  /// Engraves a piece and prepares it to be played.
  /// - Parameters:
  ///   - score: The piece.
  ///   - engraver: Who draws it.
  public func load(_ score: Score, using engraver: ScoreEngraver) {
    let xml = MusicXMLExporter.musicXML(for: score)

    guard engraver.load(musicXML: xml) else {
      failure = "Não consegui gravar esta partitura."
      return
    }

    pages = (1...max(engraver.pageCount, 1)).compactMap { engraver.page($0) }
    events = engraver.events()
    failure = pages.isEmpty ? "A gravação não produziu página nenhuma." : nil

    session = ExerciseSession(
      exercise: Exercise(items: events.map { ExerciseItem(pitches: Set($0.pitches)) }))
    refresh()
  }

  /// Whether the last press was wrong, so the cursor can read as a mistake.
  private var lastWasWrong = false

  /// Applies one key press.
  /// - Parameter pitch: The key that was struck.
  public func play(_ pitch: Pitch) {
    guard var session else { return }

    let outcome = session.press(pitch, at: Date().timeIntervalSinceReferenceDate)
    self.session = session
    lastWasWrong = outcome == .wrong
    refresh()

    if outcome == .finished { onFinished() }
  }

  /// Rebuilds the highlights from where the cursor now is.
  private func refresh() {
    guard let session else { return }
    var marks: [String: ItemState] = [:]

    for (index, event) in events.enumerated() {
      let state: ItemState
      if index < session.cursorIndex {
        state = .done
      } else if index == session.cursorIndex {
        state = lastWasWrong ? .failed : .current
      } else {
        continue
      }

      for id in event.elementIDs { marks[id] = state }
    }

    highlights = marks
    focus =
      events.indices.contains(session.cursorIndex)
      ? events[session.cursorIndex].elementIDs.first : nil
  }
}
