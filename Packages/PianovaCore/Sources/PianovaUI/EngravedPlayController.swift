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

  /// Each page's measures with their bar and frame, for hit-testing drags.
  private var measureFramesByPage: [[(bar: Int, frame: CGRect)]] = []

  /// Ready engravings of recent scores, so leaving study is instant.
  ///
  /// Tapping "Concluir" re-engraved the whole piece from scratch, seconds of
  /// stall that read as a dead button — and the second tap landed on whatever
  /// button appeared under the finger. The whole piece was engraved once
  /// already; it is restored, not redone.
  private var engravings: [(score: Score, engraved: Engraving)] = []

  /// Everything one engraving produced, kept together so it can be swapped in.
  private struct Engraving {
    var pages: [EngravedPage]
    var events: [EngravedEvent]
    var columnOfEvent: [Int]
    var staffOfEvent: [Int]
    var barOfColumn: [Int]
    var eventOfColumn: [Int: Int]
    var columnOfElement: [String: Int]
    var measureIDsOfBar: [Int: Set<String>]
    var measureFramesByPage: [[(bar: Int, frame: CGRect)]]
  }

  /// Creates an empty controller, ready to be handed a piece.
  public init() {}

  /// Engraves a piece and prepares it to be played.
  /// - Parameters:
  ///   - score: The piece.
  ///   - engraver: Who draws it.
  public func load(_ score: Score, using engraver: ScoreEngraver) {
    if let ready = engravings.first(where: { $0.score == score }) {
      apply(ready.engraved)
      remember(score, ready.engraved)
      restrict(to: nil, hands: .both)
      return
    }

    let xml = MusicXMLExporter.musicXML(for: score)

    guard engraver.load(musicXML: xml) else {
      failure = "Não consegui gravar esta partitura."
      return
    }

    let pages = (1...max(engraver.pageCount, 1)).compactMap { engraver.page($0) }
    let events = engraver.events()
    failure = pages.isEmpty ? "A gravação não produziu página nenhuma." : nil

    let columnOfEvent = score.soundingColumns

    // Which hand an event belongs to comes from the score, not the drawing: the
    // upper staff's notes are the right hand's, whatever register they sit in.
    let columns = score.columns
    let staffOfEvent = columnOfEvent.map { column -> Int in
      guard columns.indices.contains(column) else { return 1 }
      return columns[column].upper.isEmpty ? 2 : 1
    }

    let barOfColumn = columns.indices.map { score.measureNumber(atColumn: $0) }

    var columnOfElement: [String: Int] = [:]
    for (event, column) in columnOfEvent.enumerated() {
      guard events.indices.contains(event) else { continue }
      for id in events[event].elementIDs { columnOfElement[id] = column }
    }

    var measureIDsOfBar: [Int: Set<String>] = [:]
    for page in pages {
      for shape in page.shapes {
        guard let measure = shape.measureID, let note = shape.noteID,
          let column = columnOfElement[note], barOfColumn.indices.contains(column)
        else { continue }
        measureIDsOfBar[barOfColumn[column], default: []].insert(measure)
      }
    }

    var barOfMeasureID: [String: Int] = [:]
    for (bar, ids) in measureIDsOfBar {
      for id in ids { barOfMeasureID[id] = bar }
    }

    let engraved = Engraving(
      pages: pages,
      events: events,
      columnOfEvent: columnOfEvent,
      staffOfEvent: staffOfEvent,
      barOfColumn: barOfColumn,
      eventOfColumn: Dictionary(
        columnOfEvent.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first }),
      columnOfElement: columnOfElement,
      measureIDsOfBar: measureIDsOfBar,
      measureFramesByPage: pages.map { page in
        barOfMeasureID.compactMap { id, bar in
          page.measureFrame(id).map { (bar: bar, frame: $0) }
        }
      })

    apply(engraved)
    remember(score, engraved)
    restrict(to: nil, hands: .both)
  }

  /// Swaps a ready engraving in.
  private func apply(_ engraved: Engraving) {
    pages = engraved.pages
    events = engraved.events
    columnOfEvent = engraved.columnOfEvent
    staffOfEvent = engraved.staffOfEvent
    barOfColumn = engraved.barOfColumn
    eventOfColumn = engraved.eventOfColumn
    columnOfElement = engraved.columnOfElement
    measureIDsOfBar = engraved.measureIDsOfBar
    measureFramesByPage = engraved.measureFramesByPage
  }

  /// Keeps the most recent engravings, the piece and its current passage.
  private func remember(_ score: Score, _ engraved: Engraving) {
    engravings.removeAll { $0.score == score }
    engravings.insert((score, engraved), at: 0)
    if engravings.count > 2 { engravings.removeLast(engravings.count - 2) }
  }

  /// Which bar sits under a point on a page, for dragging a handle across.
  /// - Parameters:
  ///   - point: A point in the page's own coordinates.
  ///   - pageIndex: Which page it is on.
  /// - Returns: The bar there, or the nearest one on that line of music.
  public func bar(atPagePoint point: CGPoint, pageIndex: Int) -> Int? {
    guard measureFramesByPage.indices.contains(pageIndex) else { return nil }
    let frames = measureFramesByPage[pageIndex]

    // The bar whose box holds the point; failing that, the nearest box whose
    // vertical band holds it, so a drag along a system never loses the line.
    if let hit = frames.first(where: { $0.frame.insetBy(dx: -4, dy: -12).contains(point) }) {
      return hit.bar
    }

    return
      frames
      .filter { point.y >= $0.frame.minY - 20 && point.y <= $0.frame.maxY + 20 }
      .min(by: { distance($0.frame, to: point) < distance($1.frame, to: point) })?
      .bar
  }

  /// The frame of one bar on one page, for placing its selection handles.
  /// - Parameters:
  ///   - bar: The bar number.
  ///   - pageIndex: Which page to look on.
  /// - Returns: Its box in page coordinates, or `nil` if it is not there.
  public func frameOfBar(_ bar: Int, pageIndex: Int) -> CGRect? {
    guard measureFramesByPage.indices.contains(pageIndex) else { return nil }
    let boxes = measureFramesByPage[pageIndex].filter { $0.bar == bar }.map { $0.frame }
    guard let first = boxes.first else { return nil }
    return boxes.dropFirst().reduce(first) { $0.union($1) }
  }

  private func distance(_ frame: CGRect, to point: CGPoint) -> CGFloat {
    let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
    let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
    return dx * dx + dy * dy
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
