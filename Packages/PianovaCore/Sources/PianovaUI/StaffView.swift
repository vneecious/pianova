import CoreText
import ScoreModel
import SwiftUI

/// A note head drawn at a bare staff position.
///
/// Used to reveal an answer: where the player pointed, and where it was.
public struct StaffMark: Equatable, Sendable {
  /// Half-spaces above the bottom line.
  public let step: Int

  /// How it should read.
  public let state: ItemState

  /// Creates a mark.
  /// - Parameters:
  ///   - step: Half-spaces above the bottom line.
  ///   - state: How it should read.
  public init(step: Int, state: ItemState) {
    self.step = step
    self.state = state
  }
}

/// How one item of a sequence should read at a glance.
public enum ItemState: Equatable, Sendable {
  /// Already cleared.
  case done
  /// The item the cursor marks right now.
  case current
  /// Still ahead.
  case pending
  /// The item that was just missed.
  case failed
}

/// Draws a staff with its clef and a row of note heads.
///
/// Vertical placement comes from ``Pitch/staffStep(in:)``, which is pure logic
/// covered by tests. This view only turns steps into points, and knows nothing
/// about exercises or quizzes.
public struct StaffView: View, @MainActor Animatable {
  @Environment(\.colorScheme) private var colorScheme

  /// The clef to draw and to place the pitches against.
  public let clef: Clef

  /// Groups of pitches, drawn left to right.
  ///
  /// Each group is one column, so a chord is a group with several pitches.
  public let noteGroups: [[Pitch]]

  /// Visual state for each group, parallel to `noteGroups`.
  public let states: [ItemState]

  /// Written duration for each group, parallel to `noteGroups`.
  ///
  /// Leave empty to draw plain note heads, which is right for reading drills
  /// where duration is not the subject.
  public let durations: [Duration]

  /// Distance between two staff lines, in points.
  public let staffSpace: CGFloat

  /// Bare positions drawn on the staff, for revealing an answer.
  public let marks: [StaffMark]

  /// Whether to draw faint guides where ledger lines would go.
  ///
  /// A placement card asks for a note that may sit outside the five lines. With
  /// nothing drawn there, the player has no reference to aim at above or below
  /// the staff.
  public let showsLedgerGuides: Bool

  /// Steps offered as tap targets, laid out as a diagonal staircase.
  ///
  /// Steps are half a staff space apart, far tighter than a finger. Giving each
  /// one its own column keeps them a comfortable distance apart without moving
  /// them off the line or space they stand for. Leave empty to let a tap land
  /// anywhere on the staff.
  public let tapTargets: [Int]

  /// Called with the nearest staff step when the staff is tapped.
  ///
  /// Leave `nil` for a staff that only displays.
  public let onTapStep: ((Int) -> Void)?

  /// The time signature to write after the clef, or `nil` for none.
  public let timeSignature: TimeSignature?

  /// The key signature to write after the clef.
  public let key: KeySignature

  /// Runs of columns joined by a beam, in this staff's own indices.
  public let beamGroups: [Range<Int>]

  /// Column indices after which a bar line falls.
  ///
  /// Given as indices rather than derived here, because where a bar ends is a
  /// fact about the music and this view only draws.
  public let barlinesAfter: Set<Int>

  /// Whether to close with a double bar line.
  public let showsFinalBarline: Bool

  /// Where the moving guide line is, or `nil` when nothing is playing.
  ///
  /// Given in this staff's own columns, so a system knows nothing about the
  /// systems around it.
  public let playhead: PlayheadPosition?

  /// Whether this line is stretched to fill the width.
  ///
  /// Every system except the last, as printed music does.
  public let justifies: Bool

  /// Number written above the left end, or `nil` for none.
  ///
  /// Printed music numbers the first bar of each system. Here it is more than
  /// convention: the app talks in bars — "let us retake this bar", "bar 7 has a
  /// note with no duration" — and without the number there is no way to tell
  /// which one it means.
  public let measureNumber: Int?

  /// Whether the music keeps a fixed spacing and scrolls under the clef.
  ///
  /// A generated drill is short and always fits, so it does not scroll. A piece
  /// is as long as it is, and squeezing it into the width makes a line nobody
  /// can read.
  public let scrolls: Bool

  /// The column to hold at the cursor anchor while scrolling.
  ///
  /// Fractional and `var` so SwiftUI can interpolate it: an `Int` can only
  /// jump, and the stave snapping from note to note is what makes following it
  /// feel like work.
  public var focusColumn: Double

  /// Creates a staff view.
  /// - Parameters:
  ///   - clef: The clef to draw.
  ///   - noteGroups: Groups of pitches, one column each, left to right.
  ///   - states: Visual state for each group, parallel to `noteGroups`.
  ///   - durations: Written duration per group, or empty for plain heads.
  ///   - marks: Bare positions to draw, for revealing an answer.
  ///   - showsLedgerGuides: Whether to draw faint guides outside the staff.
  ///   - tapTargets: Steps offered as tap targets, ascending.
  ///   - staffSpace: Distance between two staff lines, in points.
  ///   - timeSignature: The time signature to write, or `nil` for none.
  ///   - key: The key signature to write.
  ///   - barlinesAfter: Column indices after which a bar line falls.
  ///   - beamGroups: Runs of columns joined by a beam.
  ///   - showsFinalBarline: Whether to close with a double bar line.
  ///   - measureNumber: Number to write above the left end, or `nil`.
  ///   - playhead: Where the guide line is, or `nil` when nothing plays.
  ///   - justifies: Whether the line is stretched to fill the width.
  ///   - scrolls: Whether the music keeps a fixed spacing and scrolls.
  ///   - focusColumn: The column to hold at the cursor anchor.
  ///   - onTapStep: Called with the step that was tapped.
  public init(
    clef: Clef,
    noteGroups: [[Pitch]],
    states: [ItemState],
    durations: [Duration] = [],
    marks: [StaffMark] = [],
    showsLedgerGuides: Bool = false,
    tapTargets: [Int] = [],
    staffSpace: CGFloat = 16,
    timeSignature: TimeSignature? = nil,
    key: KeySignature = .c,
    barlinesAfter: Set<Int> = [],
    beamGroups: [Range<Int>] = [],
    showsFinalBarline: Bool = false,
    measureNumber: Int? = nil,
    playhead: PlayheadPosition? = nil,
    justifies: Bool = false,
    scrolls: Bool = false,
    focusColumn: Double = 0,
    onTapStep: ((Int) -> Void)? = nil
  ) {
    self.clef = clef
    self.noteGroups = noteGroups
    self.states = states
    self.durations = durations
    self.marks = marks
    self.showsLedgerGuides = showsLedgerGuides
    self.tapTargets = tapTargets
    self.staffSpace = staffSpace
    self.timeSignature = timeSignature
    self.key = key
    self.barlinesAfter = barlinesAfter
    self.beamGroups = beamGroups
    self.showsFinalBarline = showsFinalBarline
    self.measureNumber = measureNumber
    self.playhead = playhead
    self.justifies = justifies
    self.scrolls = scrolls
    self.focusColumn = focusColumn
    self.onTapStep = onTapStep
  }

  /// What SwiftUI interpolates when the cursor moves.
  ///
  /// Without this the whole staff is simply redrawn at the new position, which
  /// reads as a jump however long the animation is asked to last.
  public var animatableData: Double {
    get { focusColumn }
    set { focusColumn = newValue }
  }

  /// Smallest comfortable distance between two touch targets.
  private static let touchSpacing: CGFloat = 46

  /// How far a tap may land from a target and still count.
  private static let touchSlack: CGFloat = 26

  private var targetFirstX: CGFloat { staffSpace * 5.5 }

  private func targetSpacing(width: CGFloat) -> CGFloat {
    let available = width - targetFirstX - staffSpace
    let gaps = CGFloat(max(tapTargets.count - 1, 1))
    return min(62, max(Self.touchSpacing, available / gaps))
  }

  /// Staff spaces of headroom kept above and below for ledger lines.
  private var margin: CGFloat { staffSpace * 4 }

  private var staffHeight: CGFloat { staffSpace * 4 }

  /// Maps steps to points, and taps back to steps.
  private var geometry: StaffGeometry {
    StaffGeometry(staffSpace: staffSpace, bottomLineY: margin + staffHeight)
  }

  /// The staff, its clef and the note heads.
  public var body: some View {
    GeometryReader { proxy in
      Canvas { context, size in
        let bottomLineY = margin + staffHeight
        if showsLedgerGuides {
          drawLedgerGuides(in: context, width: size.width, bottomLineY: bottomLineY)
        }
        drawCursorBand(in: context, size: size, bottomLineY: bottomLineY)
        drawStaffLines(in: context, width: size.width, bottomLineY: bottomLineY)
        drawBarlines(in: context, size: size, bottomLineY: bottomLineY)
        drawTargets(in: context, width: size.width)
        drawGlyphs(in: context, size: size, bottomLineY: bottomLineY)
        drawPlayhead(in: context, size: size)
      }
      .contentShape(Rectangle())
      .onTapGesture(coordinateSpace: .local) { location in
        handleTap(at: location, width: proxy.size.width)
      }
    }
    .frame(height: staffHeight + margin * 2)
    .overlay(alignment: .topLeading) { measureBadge }
  }

  /// With targets on offer only a target counts; otherwise a tap snaps to the
  /// nearest step anywhere on the staff.
  private func handleTap(at location: CGPoint, width: CGFloat) {
    guard !tapTargets.isEmpty else {
      onTapStep?(geometry.step(atY: location.y))
      return
    }

    guard
      let step = geometry.nearestTarget(
        to: location,
        among: tapTargets,
        firstX: targetFirstX,
        spacing: targetSpacing(width: width),
        maxDistance: Self.touchSlack)
    else { return }

    onTapStep?(step)
  }

  /// The bar number above the left end of the system.
  @ViewBuilder
  private var measureBadge: some View {
    if let measureNumber, measureNumber > 0 {
      Text("\(measureNumber)")
        .font(.system(size: staffSpace * 0.62, weight: .medium, design: .serif))
        .foregroundStyle(.secondary)
        .padding(.leading, staffSpace * 0.6)
    }
  }

  private func drawTargets(in context: GraphicsContext, width: CGFloat) {
    guard !tapTargets.isEmpty else { return }

    let positions = geometry.targetPositions(
      steps: tapTargets,
      firstX: targetFirstX,
      spacing: targetSpacing(width: width))

    for position in positions {
      let radius: CGFloat = 11
      let circle = Path(
        ellipseIn: CGRect(
          x: position.x - radius, y: position.y - radius,
          width: radius * 2, height: radius * 2))

      context.fill(circle, with: .color(.primary.opacity(0.05)))
      context.stroke(circle, with: .color(ItemState.current.color.opacity(0.45)), lineWidth: 1.5)
    }
  }

  private func y(step: Int, bottomLineY: CGFloat) -> CGFloat {
    bottomLineY - CGFloat(step) * staffSpace / 2
  }

  private func drawStaffLines(
    in context: GraphicsContext, width fullWidth: CGFloat, bottomLineY: CGFloat
  ) {
    // Staff lines stop where the music does on a short last system: paper after
    // the final bar line is not something printed music has.
    let width = layout(width: fullWidth).staffLineEnd
    for line in 0...4 {
      var path = Path()
      let lineY = y(step: line * 2, bottomLineY: bottomLineY)
      path.move(to: CGPoint(x: 0, y: lineY))
      path.addLine(to: CGPoint(x: width, y: lineY))
      context.stroke(path, with: .color(.primary.opacity(0.55)), lineWidth: 1)
    }
  }

  /// Faint dashed lines where ledger lines would be, so a tap outside the five
  /// staff lines has something to aim at.
  private func drawLedgerGuides(
    in context: GraphicsContext, width: CGFloat, bottomLineY: CGFloat
  ) {
    let style = StrokeStyle(lineWidth: 1, dash: [3, 5])

    for step in [-6, -4, -2, 10, 12, 14] {
      var path = Path()
      let guideY = y(step: step, bottomLineY: bottomLineY)
      path.move(to: CGPoint(x: 0, y: guideY))
      path.addLine(to: CGPoint(x: width, y: guideY))
      context.stroke(path, with: .color(.primary.opacity(0.16)), style: style)
    }
  }

  private func drawGlyphs(in context: GraphicsContext, size: CGSize, bottomLineY: CGFloat) {
    let font = Bravura.font(staffSpace: staffSpace)
    // One source of truth for the across-the-page maths, shared with anything
    // that has to line up with the note heads.
    let layout = layout(width: size.width)
    let shift = layout.offset(focusing: focusColumn)
    let clefX = layout.clefX
    let clefBaseline = y(step: clef == .treble ? 2 : 6, bottomLineY: bottomLineY)
    let firstNoteX = layout.noteAreaStart
    let available = layout.noteAreaWidth
    let spacing = layout.spacing

    context.withCGContext { cgContext in
      draw(
        clef == .treble ? Bravura.Glyph.trebleClef : Bravura.Glyph.bassClef,
        at: CGPoint(x: clefX, y: clefBaseline),
        color: PlatformColor.staffInk(colorScheme),
        font: font,
        in: cgContext,
        canvasHeight: size.height,
        centered: false)

      drawPreamble(
        in: cgContext, startX: layout.preambleStart, bottomLineY: bottomLineY,
        font: font, canvasHeight: size.height)

      // Clipped to the note area so the music slides *under* the clef and the
      // signatures instead of over them.
      cgContext.saveGState()
      cgContext.clip(
        to: CGRect(
          x: firstNoteX, y: 0,
          width: max(size.width - firstNoteX, 0), height: size.height))

      for (index, group) in noteGroups.enumerated() {
        let state = index < states.count ? states[index] : .pending
        let noteX = layout.x(ofColumn: index) - shift
        let room = layout.width(ofColumn: index)
        guard noteX > firstNoteX - room, noteX < size.width + room else { continue }
        // An empty group is a rest: drawn on the middle line, in its own
        // figure, so a silence reads as a silence and not as a missing note.
        if group.isEmpty {
          let value = durations.indices.contains(index) ? durations[index].value : .quarter
          draw(
            Bravura.Glyph.rest(for: value),
            at: CGPoint(x: noteX, y: y(step: 4, bottomLineY: bottomLineY)),
            color: PlatformColor.ink(for: state, in: colorScheme),
            font: font, in: cgContext, canvasHeight: size.height, centered: true)
          continue
        }

        let isBeamed = beamGroups.contains { $0.contains(index) }

        for pitch in group.sorted(by: { $0.midiNoteNumber < $1.midiNoteNumber }) {
          drawNote(
            pitch, state: state,
            // A beamed note is drawn as a bare head: its stem and flag would
            // fight the beam that is about to be drawn over it.
            duration: isBeamed
              ? nil : (durations.indices.contains(index) ? durations[index] : nil),
            at: noteX, bottomLineY: bottomLineY,
            font: font, in: cgContext, canvasHeight: size.height)
        }
      }

      for group in beamGroups {
        drawBeamGroup(
          group, in: context, cgContext: cgContext, layout: layout, shift: shift,
          bottomLineY: bottomLineY, font: font, canvasHeight: size.height)
      }

      cgContext.restoreGState()

      drawMarks(
        in: cgContext, firstNoteX: firstNoteX, available: available,
        bottomLineY: bottomLineY, font: font, canvasHeight: size.height)
    }
  }

  // MARK: - Bar lines, time signature, key signature

  /// Staff steps the key signature accidentals are written on.
  ///
  /// The order and the octave are fixed by convention and never vary, so they
  /// are a table rather than a calculation. Bass clef sits two steps lower than
  /// treble, which is exactly the interval between the two clefs.
  private static let sharpSteps: [Clef: [Int]] = [
    .treble: [8, 5, 9, 6, 3, 7, 4],
    .bass: [6, 3, 7, 4, 1, 5, 2],
  ]

  private static let flatSteps: [Clef: [Int]] = [
    .treble: [4, 7, 3, 6, 2, 5, 1],
    .bass: [2, 5, 1, 4, 0, 3, -1],
  ]

  /// Staff steps a key signature's accidentals are written on.
  ///
  /// Shared with the grand staff, which writes the same signature twice — once
  /// per staff — and must put it in the same conventional places.
  /// - Parameters:
  ///   - key: The key signature.
  ///   - clef: Which staff it is being written on.
  /// - Returns: The steps, in writing order.
  static func accidentalSteps(for key: KeySignature, clef: Clef) -> [Int] {
    (key.usesSharps ? sharpSteps : flatSteps)[clef] ?? []
  }

  /// The across-the-page maths for a given width, in one place.
  private func layout(width: CGFloat) -> StaffLayout {
    StaffLayout(
      staffSpace: staffSpace, width: width, columnCount: noteGroups.count,
      preamble: preambleWidth, scrolls: scrolls, durations: durations,
      justifies: justifies)
  }

  /// How much room the clef, key and time signature take before the first note.
  private var preambleWidth: CGFloat {
    CGFloat(key.accidentalCount) * staffSpace * 0.9
      + (timeSignature == nil ? 0 : staffSpace * 2.2)
  }

  /// A soft band behind the note the cursor is on.
  ///
  /// Drawn whether or not anything has been played yet: having to hunt for
  /// where you are is the thing that breaks the flow of reading, and it costs
  /// nothing to say it outright.
  /// The moving guide line, placed by the same arithmetic as the note heads.
  private func drawPlayhead(in context: GraphicsContext, size: CGSize) {
    guard let playhead else { return }

    let bottomLineY = margin + staffHeight

    let layout = layout(width: size.width)
    let positionX =
      layout.playheadX(column: playhead.column, progress: playhead.progress)
      - layout.offset(focusing: focusColumn)

    guard positionX >= layout.noteAreaStart - staffSpace, positionX <= size.width else { return }

    var path = Path()
    path.move(to: CGPoint(x: positionX, y: bottomLineY - staffHeight - staffSpace))
    path.addLine(to: CGPoint(x: positionX, y: bottomLineY + staffSpace))
    context.stroke(path, with: .color(ItemState.current.color.opacity(0.7)), lineWidth: 2)
  }

  private func drawCursorBand(in context: GraphicsContext, size: CGSize, bottomLineY: CGFloat) {
    guard scrolls, noteGroups.count > 0 else { return }

    let layout = layout(width: size.width)
    let column = Int(focusColumn.rounded())
    guard column < noteGroups.count else { return }

    let shift = layout.offset(focusing: focusColumn)
    let room = layout.width(ofColumn: column)
    let left = layout.noteAreaStart + layout.start(ofColumn: column) - shift

    let band = CGRect(
      x: left, y: bottomLineY - staffHeight - staffSpace,
      width: room, height: staffHeight + staffSpace * 2)

    guard band.maxX > layout.noteAreaStart else { return }

    context.fill(
      Path(roundedRect: band, cornerRadius: staffSpace * 0.4),
      with: .color(ItemState.current.color.opacity(0.10)))
  }

  /// A bar line between two columns, and the double bar that closes the piece.
  private func drawBarlines(in context: GraphicsContext, size: CGSize, bottomLineY: CGFloat) {
    guard !barlinesAfter.isEmpty || showsFinalBarline else { return }

    let layout = layout(width: size.width)
    let shift = layout.offset(focusing: focusColumn)
    let visible = layout.noteAreaStart...(layout.noteAreaStart + layout.noteAreaWidth)
    let top = bottomLineY - staffHeight
    let ink = PlatformColor.staffInk(colorScheme)

    func line(at positionX: CGFloat, thick: Bool) {
      guard visible.contains(positionX) else { return }
      var path = Path()
      path.move(to: CGPoint(x: positionX, y: top))
      path.addLine(to: CGPoint(x: positionX, y: bottomLineY))
      context.stroke(path, with: .color(Color(ink)), lineWidth: thick ? 3 : 1)
    }

    for index in barlinesAfter where index < noteGroups.count - 1 {
      line(at: layout.noteAreaStart + layout.start(ofColumn: index + 1) - shift, thick: false)
    }

    if showsFinalBarline {
      let end = layout.noteAreaStart + layout.contentWidth - shift
      line(at: end - staffSpace * 0.5, thick: false)
      line(at: end, thick: true)
    }
  }

  /// The key signature and the time signature, written between clef and notes.
  private func drawPreamble(
    in cgContext: CGContext,
    startX: CGFloat,
    bottomLineY: CGFloat,
    font: CTFont,
    canvasHeight: CGFloat
  ) {
    let ink = PlatformColor.staffInk(colorScheme)
    var cursor = startX

    let steps = Self.accidentalSteps(for: key, clef: clef)
    let glyph = key.usesSharps ? Bravura.Glyph.sharp : Bravura.Glyph.flat

    for index in 0..<key.accidentalCount where index < steps.count {
      draw(
        glyph,
        at: CGPoint(x: cursor, y: y(step: steps[index], bottomLineY: bottomLineY)),
        color: ink, font: font, in: cgContext, canvasHeight: canvasHeight, centered: false)
      cursor += staffSpace * 0.9
    }

    guard let time = timeSignature else { return }

    // Upper number sits on the fourth step, lower on the first: the two digits
    // straddle the middle line, which is how a time signature is engraved.
    let lower = Int((4 / time.beatValue.beats).rounded())
    for (digit, step) in [(time.beatsPerBar, 5), (lower, 1)] {
      draw(
        Bravura.Glyph.timeSignatureDigit(digit),
        at: CGPoint(x: cursor + staffSpace * 0.4, y: y(step: step, bottomLineY: bottomLineY)),
        color: ink, font: font, in: cgContext, canvasHeight: canvasHeight, centered: false)
    }
  }

  private func drawMarks(
    in cgContext: CGContext,
    firstNoteX: CGFloat,
    available: CGFloat,
    bottomLineY: CGFloat,
    font: CTFont,
    canvasHeight: CGFloat
  ) {
    guard !marks.isEmpty else { return }
    let spacing = available / CGFloat(marks.count)

    for (index, mark) in marks.enumerated() {
      let markX = firstNoteX + spacing * (CGFloat(index) + 0.5)
      let baseline = y(step: mark.step, bottomLineY: bottomLineY)
      let color = PlatformColor.ink(for: mark.state, in: colorScheme)

      drawLedgerLines(
        for: mark.step, at: markX, bottomLineY: bottomLineY, in: cgContext, color: color)
      draw(
        Bravura.Glyph.noteheadBlack,
        at: CGPoint(x: markX, y: baseline),
        color: color, font: font, in: cgContext, canvasHeight: canvasHeight, centered: true)
    }
  }

  /// Draws one beamed run: bare note heads, their own stems, and the beam.
  ///
  /// The composite glyphs carry a flag, which is exactly what a beamed note
  /// must not have, so a beamed note is drawn from a plain note head upwards.
  private func drawBeamGroup(
    _ group: Range<Int>,
    in context: GraphicsContext,
    cgContext: CGContext,
    layout: StaffLayout,
    shift: CGFloat,
    bottomLineY: CGFloat,
    font: CTFont,
    canvasHeight: CGFloat
  ) {
    let steps = group.compactMap { index -> (x: CGFloat, step: Int, state: ItemState)? in
      guard let pitch = noteGroups[index].first else { return nil }
      return (
        layout.x(ofColumn: index) - shift,
        pitch.staffStep(in: clef),
        index < states.count ? states[index] : .pending
      )
    }
    guard steps.count >= 2 else { return }

    // One direction for the whole group, decided by where its notes sit: the
    // stems of a beamed run never point different ways.
    let average = Double(steps.map(\.step).reduce(0, +)) / Double(steps.count)
    let stemUp = average < 4

    let reach = staffSpace * 3.5
    let ends = steps.map { point -> CGFloat in
      let baseline = y(step: point.step, bottomLineY: bottomLineY)
      return stemUp ? baseline - reach : baseline + reach
    }

    // A gentle slant towards where the run is going, capped so the beam never
    // looks like it is falling over.
    guard let first = ends.first, let last = ends.last else { return }
    let cap = staffSpace * 1.2
    let slant = min(max(last - first, -cap), cap)
    let beamStart = stemUp ? min(ends.min() ?? first, first) : max(ends.max() ?? first, first)
    let beamEnd = beamStart + slant

    let ink = PlatformColor.ink(for: steps.first?.state ?? .pending, in: colorScheme)
    let thickness = staffSpace * Bravura.Glyph.beamThickness

    // The beam itself, plus a second one for a run of semiquavers.
    let count =
      group.compactMap { durations.indices.contains($0) ? durations[$0].value : nil }
      .map(BeamGrouping.beams(for:)).min() ?? 1

    for level in 0..<max(count, 1) {
      let drop = CGFloat(level) * thickness * 1.8 * (stemUp ? 1 : -1)
      var path = Path()
      path.move(to: CGPoint(x: steps[0].x, y: beamStart + drop))
      path.addLine(to: CGPoint(x: steps[steps.count - 1].x, y: beamEnd + drop))
      path.addLine(
        to: CGPoint(x: steps[steps.count - 1].x, y: beamEnd + drop + thickness))
      path.addLine(to: CGPoint(x: steps[0].x, y: beamStart + drop + thickness))
      path.closeSubpath()
      context.fill(path, with: .color(Color(ink)))
    }

    for (index, point) in steps.enumerated() {
      let baseline = y(step: point.step, bottomLineY: bottomLineY)
      let fraction =
        steps.count > 1 ? CGFloat(index) / CGFloat(steps.count - 1) : 0
      let top = beamStart + slant * fraction

      var stem = Path()
      stem.move(to: CGPoint(x: point.x, y: baseline))
      stem.addLine(to: CGPoint(x: point.x, y: top + thickness / 2))
      context.stroke(
        stem, with: .color(Color(PlatformColor.ink(for: point.state, in: colorScheme))),
        lineWidth: staffSpace * Bravura.Glyph.stemThickness * 2)
    }
  }

  private func drawNote(
    _ pitch: Pitch,
    state: ItemState,
    duration: Duration?,
    at noteX: CGFloat,
    bottomLineY: CGFloat,
    font: CTFont,
    in cgContext: CGContext,
    canvasHeight: CGFloat
  ) {
    let step = pitch.staffStep(in: clef)
    let baseline = y(step: step, bottomLineY: bottomLineY)
    let color = PlatformColor.ink(for: state, in: colorScheme)

    drawLedgerLines(for: step, at: noteX, bottomLineY: bottomLineY, in: cgContext, color: color)

    if pitch.requiresSharp {
      draw(
        Bravura.Glyph.sharp,
        at: CGPoint(x: noteX - staffSpace * 1.6, y: baseline),
        color: color, font: font, in: cgContext, canvasHeight: canvasHeight, centered: true)
    }

    guard let duration else {
      draw(
        Bravura.Glyph.noteheadBlack,
        at: CGPoint(x: noteX, y: baseline),
        color: color, font: font, in: cgContext, canvasHeight: canvasHeight, centered: true)
      return
    }

    // Engraving convention: from the middle line up the stem hangs down, so
    // stems stay inside the staff instead of poking out the top.
    let stemUp = step < 4
    draw(
      Bravura.glyph(for: duration, stemUp: stemUp),
      at: CGPoint(x: noteX, y: baseline),
      color: color, font: font, in: cgContext, canvasHeight: canvasHeight, centered: true)

    guard duration.isDotted else { return }

    // The dot sits in a space, never on a line: a note on a line pushes it up.
    let dotStep = step % 2 == 0 ? step + 1 : step
    draw(
      Bravura.Glyph.augmentationDot,
      at: CGPoint(x: noteX + staffSpace * 1.1, y: y(step: dotStep, bottomLineY: bottomLineY)),
      color: color, font: font, in: cgContext, canvasHeight: canvasHeight, centered: true)
  }

  private func drawLedgerLines(
    for step: Int,
    at noteX: CGFloat,
    bottomLineY: CGFloat,
    in cgContext: CGContext,
    color: CGColor
  ) {
    guard step < 0 || step > 8 else { return }
    let width = staffSpace * 1.7
    let range =
      step < 0 ? stride(from: -2, through: step, by: -2) : stride(from: 10, through: step, by: 2)

    cgContext.saveGState()
    cgContext.setStrokeColor(color)
    cgContext.setLineWidth(1)
    for ledger in range {
      let ledgerY = y(step: ledger, bottomLineY: bottomLineY)
      cgContext.move(to: CGPoint(x: noteX - width / 2, y: ledgerY))
      cgContext.addLine(to: CGPoint(x: noteX + width / 2, y: ledgerY))
    }
    cgContext.strokePath()
    cgContext.restoreGState()
  }

  /// Draws a glyph with its baseline at `point.y`.
  ///
  /// Core Text draws upwards from the baseline, while the canvas measures
  /// downwards from the top, so the context is flipped for the duration.
  private func draw(
    _ glyph: String,
    at point: CGPoint,
    color: CGColor,
    font: CTFont,
    in cgContext: CGContext,
    canvasHeight: CGFloat,
    centered: Bool
  ) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
    ]
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: glyph, attributes: attributes))
    let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

    cgContext.saveGState()
    cgContext.textMatrix = .identity
    cgContext.translateBy(x: 0, y: canvasHeight)
    cgContext.scaleBy(x: 1, y: -1)
    cgContext.textPosition = CGPoint(
      x: centered ? point.x - width / 2 : point.x,
      y: canvasHeight - point.y)
    CTLineDraw(line, cgContext)
    cgContext.restoreGState()
  }
}
