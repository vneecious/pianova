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

  /// Whether an engraving is running right now, for the screen to say so.
  ///
  /// Engraving a long piece takes seconds, and those seconds used to happen
  /// on the main thread — the screen froze with no explanation, which reads
  /// as broken. Now the work happens off it and this flag is the explanation.
  @Published public private(set) var isEngraving = false

  /// Each page's ink as images, rendered off the main thread.
  ///
  /// Keyed by page and resting staff. The screen paints these once and draws
  /// only highlights over them — the redraw-everything path is what froze
  /// long pieces.
  @Published public private(set) var inkMasks: [String: InkRasterizer.Masks] = [:]

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

  /// The ornament pitches decorating each column, excused from judgement
  /// (rule 127): played, a grace neither advances nor punishes.
  private var gracesOfColumn: [[Pitch]] = []

  /// The pedal mark at each column, for the optional pedal judging.
  private var pedalOfColumn: [PedalMark?] = []

  /// Whether the written pedal is judged (rule 140) — optional, like hands.
  public var judgesPedal = false

  /// The sustain pedal's state right now, from the instrument.
  public private(set) var sustainIsDown = false

  /// Feeds the sustain pedal's state from the instrument.
  /// - Parameter isDown: Whether the pedal is pressed.
  public func setSustain(_ isDown: Bool) {
    sustainIsDown = isDown
  }

  /// What each staff carries at each column, for judging note by note.
  ///
  /// Where the hands play together, the studied hand answers for its own
  /// notes and no others — classifying whole events by one staff made a
  /// one-hand study wait for the other hand exactly where they coincide.
  private var upperOfColumn: [Set<Pitch>] = []
  private var lowerOfColumn: [Set<Pitch>] = []

  /// Which staff each drawn note sits on, to highlight only the hand in study.
  private var staffOfElement: [String: Int] = [:]

  /// The notes each judged event actually asks for, hand filter applied.
  private var judgedPitches: [Set<Pitch>] = []

  /// The hands in study, kept for filtering what the cursor lights up.
  private var currentHands: PracticeHands = .both

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
  private var engravings: [(score: Score, units: Int, engraved: Engraving)] = []

  /// Everything one engraving produced, kept together so it can be swapped in.
  private struct Engraving {
    var pages: [EngravedPage]
    var events: [EngravedEvent]
    var columnOfEvent: [Int]
    var upperOfColumn: [Set<Pitch>]
    var lowerOfColumn: [Set<Pitch>]
    var gracesOfColumn: [[Pitch]]
    var pedalOfColumn: [PedalMark?]
    var staffOfElement: [String: Int]
    var barOfColumn: [Int]
    var eventOfColumn: [Int: Int]
    var columnOfElement: [String: Int]
    var measureIDsOfBar: [Int: Set<String>]
    var measureFramesByPage: [[(bar: Int, frame: CGRect)]]
  }

  /// Creates an empty controller, ready to be handed a piece.
  public init() {}

  /// Page width handed to the engraver, in its own units.
  ///
  /// Smaller is zoomed in: fewer units across the line, each bar drawn
  /// larger, and the page reflows.
  public var pageUnits = 2100

  /// The engraving under way, so a newer request replaces an older one.
  private var engraveTask: Task<Void, Never>?

  /// Engraves a piece and prepares it to be played, reusing a ready engraving
  /// when there is one.
  ///
  /// A cache hit lands synchronously — leaving study must be immediate. A
  /// miss engraves off the main thread, with ``isEngraving`` raised so the
  /// screen can say what is happening instead of freezing.
  /// - Parameters:
  ///   - score: The piece.
  ///   - engraver: Who draws it.
  ///   - hands: The hand restriction to apply once the pages land.
  public func load(
    _ score: Score, using engraver: ScoreEngraver, hands: PracticeHands = .both
  ) {
    engraveTask?.cancel()

    if let ready = engravings.first(where: { $0.score == score && $0.units == pageUnits }) {
      apply(ready.engraved)
      remember(score, ready.engraved)
      restrict(to: nil, hands: hands)
      isEngraving = false
      return
    }

    isEngraving = true
    let units = pageUnits

    engraveTask = Task.detached(priority: .userInitiated) { [weak self] in
      let engraved = Self.engrave(score, with: engraver, units: units)

      await MainActor.run { [weak self] in
        guard let self, !Task.isCancelled else { return }
        self.isEngraving = false

        guard let engraved else {
          self.failure = "Não consegui gravar esta partitura."
          return
        }

        self.failure =
          engraved.pages.isEmpty ? "A gravação não produziu página nenhuma." : nil
        self.apply(engraved)
        self.remember(score, engraved)
        self.restrict(to: nil, hands: hands)
        self.renderInks()
      }
    }
  }

  /// The whole engraving, done wherever it is called from.
  private nonisolated static func engrave(
    _ score: Score, with engraver: ScoreEngraver, units: Int
  ) -> Engraving? {
    let xml = MusicXMLExporter.musicXML(for: score)

    guard engraver.load(musicXML: xml, width: units, height: 2970) else { return nil }

    let pages = (1...max(engraver.pageCount, 1)).compactMap { engraver.page($0) }
    let events = engraver.events()

    let columnOfEvent = score.soundingColumns

    // Which hand a note belongs to comes from the score, not the drawing: the
    // upper staff's notes are the right hand's, whatever register they sit in.
    let columns = score.columns
    let upperOfColumn = columns.map { Set($0.upper) }
    let gracesOfColumn = score.columnGraces
    let pedalOfColumn = score.columnPedals
    let lowerOfColumn = columns.map { Set($0.lower) }

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

    var staffOfElement: [String: Int] = [:]
    for page in pages {
      for shape in page.shapes {
        guard let note = shape.noteID, let staff = shape.staffNumber else { continue }
        staffOfElement[note] = staff
      }
    }

    return Engraving(
      pages: pages,
      events: events,
      columnOfEvent: columnOfEvent,
      upperOfColumn: upperOfColumn,
      lowerOfColumn: lowerOfColumn,
      gracesOfColumn: gracesOfColumn,
      pedalOfColumn: pedalOfColumn,
      staffOfElement: staffOfElement,
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
  }

  /// Swaps a ready engraving in.
  private func apply(_ engraved: Engraving) {
    pages = engraved.pages
    events = engraved.events
    columnOfEvent = engraved.columnOfEvent
    upperOfColumn = engraved.upperOfColumn
    lowerOfColumn = engraved.lowerOfColumn
    gracesOfColumn = engraved.gracesOfColumn
    pedalOfColumn = engraved.pedalOfColumn
    staffOfElement = engraved.staffOfElement
    barOfColumn = engraved.barOfColumn
    eventOfColumn = engraved.eventOfColumn
    columnOfElement = engraved.columnOfElement
    measureIDsOfBar = engraved.measureIDsOfBar
    measureFramesByPage = engraved.measureFramesByPage
  }

  /// Keeps the most recent engravings, the piece and its current passage.
  private func remember(_ score: Score, _ engraved: Engraving) {
    engravings.removeAll { $0.score == score && $0.units == pageUnits }
    engravings.insert((score, pageUnits, engraved), at: 0)
    if engravings.count > 3 { engravings.removeLast(engravings.count - 3) }
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

  /// Which bar a point is squarely inside, or nothing if it is off the music.
  ///
  /// The loose neighbour of `bar(atPagePoint:pageIndex:)`: a drag wants the
  /// nearest bar so the handle never slips off the line, but a tap wants the
  /// truth — off the staves means "deselect", and nearest-matching would make
  /// the page margins impossible to tap.
  /// - Parameters:
  ///   - point: A point in the page's own coordinates.
  ///   - pageIndex: Which page it is on.
  /// - Returns: The bar there, or `nil` for empty paper.
  public func bar(exactlyAtPagePoint point: CGPoint, pageIndex: Int) -> Int? {
    guard measureFramesByPage.indices.contains(pageIndex) else { return nil }
    return measureFramesByPage[pageIndex]
      .first { $0.frame.insetBy(dx: -6, dy: -14).contains(point) }?
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

  /// The key under which one page's ink lives right now.
  /// - Parameter page: The page.
  /// - Returns: Its cache key, tied to the staff at rest.
  public func inkKey(for page: EngravedPage) -> String {
    "\(page.id)|\(quietStaff ?? 0)|\(showsTexts ? 1 : 0)"
  }

  /// Whether the page's written texts — fingering above all — are drawn.
  ///
  /// Reading with fingers and reading without are stages of studying the
  /// same piece, so this is the player's choice and it is remembered.
  public var showsTexts = true

  /// Renders any page whose ink is not yet an image, off the main thread.
  public func renderInks() {
    for page in pages {
      let key = inkKey(for: page)
      guard inkMasks[key] == nil else { continue }
      let quiet = quietStaff
      let texts = showsTexts

      Task.detached(priority: .userInitiated) {
        let masks = InkRasterizer.masks(
          for: page, pixelWidth: 2400, quietStaff: quiet, includeTexts: texts)
        await MainActor.run { self.inkMasks[key] = masks }
      }
    }

    // Pages from engravings gone by stay out of memory.
    let alive = Set(pages.map { inkKey(for: $0) })
    inkMasks = inkMasks.filter { alive.contains($0.key) }
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
    currentHands = hands
    judged = []
    judgedPitches = []

    for index in events.indices {
      guard columnOfEvent.indices.contains(index) else { continue }
      let column = columnOfEvent[index]

      if let range, barOfColumn.indices.contains(column),
        !range.judges(bar: barOfColumn[column])
      {
        continue
      }

      // Note by note, never event by event: where the hands play together,
      // the studied hand answers for its own notes only.
      let asked = hands.sounding(
        of: Set(events[index].pitches),
        upper: upperOfColumn.indices.contains(column) ? upperOfColumn[column] : [],
        lower: lowerOfColumn.indices.contains(column) ? lowerOfColumn[column] : [])
      guard !asked.isEmpty else { continue }

      judged.append(index)
      judgedPitches.append(asked)
    }

    quietStaff = hands.quietStaff
    restart()
  }

  /// Applies one key press.
  /// - Parameter pitch: The key that was struck.
  public func play(_ pitch: Pitch) {
    guard var session else { return }

    // An ornament is read and may well be played, but it is never judged
    // (rule 127): at a decorated moment, a grace pitch that is not itself
    // demanded neither advances nor punishes.
    if judged.indices.contains(session.cursorIndex) {
      let event = judged[session.cursorIndex]
      if columnOfEvent.indices.contains(event) {
        let column = columnOfEvent[event]
        if gracesOfColumn.indices.contains(column),
          Set(gracesOfColumn[column]).contains(pitch),
          !judgedPitches[session.cursorIndex].contains(pitch)
        {
          return
        }

        // With pedal judging on (rule 140), a moment marked Ped. waits for
        // the sustain pedal before its notes count — wrong pedal never
        // punishes, it simply does not complete.
        if judgesPedal, pedalOfColumn.indices.contains(column),
          pedalOfColumn[column] == .down || pedalOfColumn[column] == .change,
          !sustainIsDown
        {
          return
        }
      }
    }

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
      exercise: Exercise(items: judgedPitches.map { ExerciseItem(pitches: $0) }))
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

      for id in litElements(of: index) { marks[id] = state }
    }

    highlights = marks
    focus =
      judged.indices.contains(session.cursorIndex)
      ? litElements(of: judged[session.cursorIndex]).first : nil
  }

  /// The drawn notes of one event that belong to the hand in study.
  ///
  /// The resting hand's note at the same moment stays faded — lighting it up
  /// as "current" would ask for it with one voice while excusing it with
  /// another.
  private func litElements(of event: Int) -> [String] {
    guard events.indices.contains(event) else { return [] }

    return events[event].elementIDs
      .filter { id in
        guard let staff = staffOfElement[id] else { return true }
        return currentHands.judges(staff: staff)
      }
  }
}
