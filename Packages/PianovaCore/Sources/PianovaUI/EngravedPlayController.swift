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

  /// Which sounding moment each event is, so the preview can be followed.
  ///
  /// The engraver lists only what sounds; the score counts silences too. The
  /// two have to be lined up or the preview would highlight the wrong note
  /// every time a piece has a rest.
  private var columnOfEvent: [Int] = []

  /// Called once the whole piece has been played.
  public var onFinished: () -> Void = {}

  /// Whether a finished passage starts again on its own.
  ///
  /// Repetition is the work. Making it cost a gesture each time is how it stops
  /// happening.
  public var loops = false

  /// What was last engraved, so a loop can start it over.
  private var loaded: (score: Score, engraver: ScoreEngraver)?

  /// Creates an empty controller, ready to be handed a piece.
  public init() {}

  /// Engraves a piece and prepares it to be played.
  /// - Parameters:
  ///   - score: The piece.
  ///   - engraver: Who draws it.
  public func load(_ score: Score, using engraver: ScoreEngraver) {
    loaded = (score, engraver)
    let xml = MusicXMLExporter.musicXML(for: score)

    guard engraver.load(musicXML: xml) else {
      failure = "Não consegui gravar esta partitura."
      return
    }

    pages = (1...max(engraver.pageCount, 1)).compactMap { engraver.page($0) }
    events = engraver.events()
    failure = pages.isEmpty ? "A gravação não produziu página nenhuma." : nil

    columnOfEvent = score.soundingColumns

    session = ExerciseSession(
      exercise: Exercise(items: events.map { ExerciseItem(pitches: Set($0.pitches)) }))
    refresh()
  }

  /// Lights up whatever sounds at one column of the score.
  ///
  /// Used while the piece plays itself: there is no cursor then, because
  /// nobody is being judged — the page simply follows the sound.
  /// - Parameter column: Index into the score's own columns.
  public func follow(column: Int) {
    guard let event = columnOfEvent.firstIndex(of: column),
      events.indices.contains(event)
    else {
      return
    }

    highlights = Dictionary(
      uniqueKeysWithValues: events[event].elementIDs.map { ($0, ItemState.current) })
    focus = events[event].elementIDs.first
  }

  /// Which column of the score a drawn note belongs to.
  ///
  /// The other direction, for tapping a note to say "play from here".
  /// - Parameter id: The element identifier that was tapped.
  /// - Returns: The column, or `nil` if that element is not a sounding note.
  public func column(of id: String) -> Int? {
    guard let event = events.firstIndex(where: { $0.elementIDs.contains(id) }),
      columnOfEvent.indices.contains(event)
    else {
      return nil
    }
    return columnOfEvent[event]
  }

  /// Puts the cursor back in charge after the preview stops.
  public func restoreCursor() {
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

    guard outcome == .finished else { return }

    if loops, let loaded {
      // Rebuilt rather than rewound: the passage is a piece of its own, and
      // starting it again is starting it again.
      load(loaded.score, using: loaded.engraver)
    } else {
      onFinished()
    }
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
