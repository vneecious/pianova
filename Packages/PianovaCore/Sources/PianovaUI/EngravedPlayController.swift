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

  /// Which staff is not being practised, so the page can fade it.
  @Published public private(set) var quietStaff: Int?

  /// Why the piece could not be engraved, if it could not.
  @Published public private(set) var failure: String?

  /// Whether a finished passage starts again on its own.
  ///
  /// Repetition is the work. Making it cost a gesture each time is how it stops
  /// happening.
  public var loops = false

  /// Called once the passage has been played through and is not looping.
  public var onFinished: () -> Void = {}

  private var events: [EngravedEvent] = []
  private var session: ExerciseSession?
  private var lastWasWrong = false

  /// Which sounding moment of the score each event is.
  ///
  /// The engraver lists only what sounds; the score counts silences too, and
  /// the two have to be lined up or everything downstream points at the wrong
  /// note whenever a piece has a rest.
  private var columnOfEvent: [Int] = []

  /// Which staff each event belongs to.
  private var staffOfEvent: [Int] = []

  /// Which events are actually being judged.
  ///
  /// Studying narrows what is judged and never what is drawn: the page stays
  /// whole, so the passage keeps its context and the next bar is still there
  /// to be chosen.
  private var judged: [Int] = []

  /// Which bar each column of the score sits in.
  ///
  /// Asked for on every tap and on every event of `restrict`, and the score
  /// recounts its bar lines each time it is asked — linear work that, done per
  /// event and per frame, is what made choosing a bar take seconds.
  private var barOfColumn: [Int] = []

  /// Which event sounds at each column, for the preview to follow.
  private var eventOfColumn: [Int: Int] = [:]

  /// Which column each drawn element belongs to, for taps.
  private var columnOfElement: [String: Int] = [:]

  /// The measures drawn in each bar, for marking a selection.
  private var measureIDsOfBar: [Int: Set<String>] = [:]

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

    columnOfEvent = score.soundingColumns

    // Which hand an event belongs to comes from the score, not the drawing: the
    // upper staff's notes are the right hand's, whatever register they sit in.
    let columns = score.columns
    staffOfEvent = columnOfEvent.map { column in
      guard columns.indices.contains(column) else { return 1 }
      return columns[column].upper.isEmpty ? 2 : 1
    }

    barOfColumn = columns.indices.map { score.measureNumber(atColumn: $0) }

    eventOfColumn = Dictionary(
      columnOfEvent.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

    columnOfElement = [:]
    for (event, column) in columnOfEvent.enumerated() {
      guard events.indices.contains(event) else { continue }
      for id in events[event].elementIDs { columnOfElement[id] = column }
    }

    measureIDsOfBar = [:]
    for page in pages {
      for shape in page.shapes {
        guard let measure = shape.measureID, let note = shape.noteID,
          let column = columnOfElement[note], barOfColumn.indices.contains(column)
        else { continue }
        measureIDsOfBar[barOfColumn[column], default: []].insert(measure)
      }
    }

    restrict(to: nil, hands: .both)
  }

  /// The measures a passage covers on the page, for drawing it as selected.
  /// - Parameter range: The bars.
  /// - Returns: The identifiers of their drawn measures.
  public func measureIDs(in range: PracticeRange?) -> Set<String> {
    guard let range else { return [] }
    return (range.first...range.last)
      .reduce(into: Set()) { set, bar in
        set.formUnion(measureIDsOfBar[bar] ?? [])
      }
  }

  /// Narrows what is judged to a passage and a hand.
  /// - Parameters:
  ///   - range: The bars to work at, or `nil` for all of them.
  ///   - hands: Which hand is being practised.
  public func restrict(to range: PracticeRange?, hands: PracticeHands) {
    judged = events.indices.filter { index in
      guard staffOfEvent.indices.contains(index) else { return true }
      guard hands.judges(staff: staffOfEvent[index]) else { return false }

      guard let range, columnOfEvent.indices.contains(index),
        barOfColumn.indices.contains(columnOfEvent[index])
      else { return true }
      return range.judges(bar: barOfColumn[columnOfEvent[index]])
    }

    quietStaff = hands.quietStaff
    restart()
  }

  /// Applies one key press.
  /// - Parameter pitch: The key that was struck.
  public func play(_ pitch: Pitch) {
    guard var session else { return }

    let outcome = session.press(pitch, at: Date().timeIntervalSinceReferenceDate)
    self.session = session
    lastWasWrong = outcome == .wrong
    refresh()

    guard outcome == .finished else { return }

    if loops {
      // Only the run starts over. The page never changed, so there is nothing
      // to redraw and no flicker between repetitions.
      restart()
    } else {
      onFinished()
    }
  }

  /// Lights up whatever sounds at one column of the score.
  ///
  /// Used while the piece plays itself: there is no cursor then, because nobody
  /// is being judged — the page simply follows the sound.
  /// - Parameter column: Index into the score's own columns.
  public func follow(column: Int) {
    guard let event = eventOfColumn[column], events.indices.contains(event)
    else {
      return
    }

    highlights = Dictionary(
      uniqueKeysWithValues: events[event].elementIDs.map { ($0, ItemState.current) })
    focus = events[event].elementIDs.first
  }

  /// Which column of the score a drawn note belongs to.
  /// - Parameter id: The element identifier that was tapped.
  /// - Returns: The column, or `nil` if that element is not a sounding note.
  public func column(of id: String) -> Int? {
    columnOfElement[id]
  }

  /// Which bar a drawn note belongs to.
  /// - Parameter id: The element identifier that was tapped.
  /// - Returns: The bar number, or `nil` for ink that is not a note.
  public func bar(of id: String) -> Int? {
    guard let column = columnOfElement[id], barOfColumn.indices.contains(column) else {
      return nil
    }
    return barOfColumn[column]
  }

  /// Puts the cursor back in charge after the preview stops.
  public func restoreCursor() {
    refresh()
  }

  /// Starts the passage again from its first note.
  private func restart() {
    session = ExerciseSession(
      exercise: Exercise(items: judged.map { ExerciseItem(pitches: Set(events[$0].pitches)) }))
    lastWasWrong = false
    refresh()
  }

  /// Rebuilds the highlights from where the cursor now is.
  private func refresh() {
    guard let session else { return }
    var marks: [String: ItemState] = [:]

    for (position, index) in judged.enumerated() {
      let state: ItemState
      if position < session.cursorIndex {
        state = .done
      } else if position == session.cursorIndex {
        state = lastWasWrong ? .failed : .current
      } else {
        continue
      }

      for id in events[index].elementIDs { marks[id] = state }
    }

    highlights = marks
    focus =
      judged.indices.contains(session.cursorIndex)
      ? events[judged[session.cursorIndex]].elementIDs.first : nil
  }
}
