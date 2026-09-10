import CoreText
import ScoreModel
import SwiftUI

/// The grand staff: treble above, bass below, joined at the left.
///
/// The two staves are placed so that middle C falls on the same point for both
/// — one ledger line under the treble staff and one over the bass staff. That
/// shared point is what makes a grand staff readable as a single system, and it
/// comes straight from ``Pitch/staffStep(in:)``, which the tests cover.
public struct GrandStaffView: View, @MainActor Animatable {
  @Environment(\.colorScheme) private var colorScheme

  /// Groups of pitches, one column each, left to right.
  ///
  /// Each pitch is routed to the staff it belongs on by
  /// ``Pitch/grandStaffClef``.
  public let noteGroups: [[Pitch]]

  /// Visual state for each group, parallel to `noteGroups`.
  public let states: [ItemState]

  /// Distance between two staff lines, in points.
  public let staffSpace: CGFloat

  /// Written duration for each group, parallel to `noteGroups`.
  public let durations: [Duration]

  /// The time signature to write after the clefs, or `nil` for none.
  public let timeSignature: TimeSignature?

  /// The key signature to write after the clefs.
  public let key: KeySignature

  /// Column indices after which a bar line falls.
  public let barlinesAfter: Set<Int>

  /// Whether to close with a double bar line.
  public let showsFinalBarline: Bool

  /// Number written above the left end, or `nil` for none.
  ///
  /// Printed music numbers the first bar of each system. Here it is more than
  /// convention: the app talks in bars — "let us retake this bar", "bar 7 has a
  /// note with no duration" — and without the number there is no way to tell
  /// which one it means.
  public let measureNumber: Int?

  /// Whether the music keeps a fixed spacing and scrolls under the clefs.
  public let scrolls: Bool

  /// The column to hold at the cursor anchor while scrolling.
  public var focusColumn: Double

  /// Creates a grand staff.
  /// - Parameters:
  ///   - noteGroups: Groups of pitches, one column each, left to right.
  ///   - states: Visual state for each group, parallel to `noteGroups`.
  ///   - staffSpace: Distance between two staff lines, in points.
  ///   - durations: Written duration per group, or empty for plain heads.
  ///   - timeSignature: The time signature to write, or `nil` for none.
  ///   - key: The key signature to write.
  ///   - barlinesAfter: Column indices after which a bar line falls.
  ///   - showsFinalBarline: Whether to close with a double bar line.
  ///   - measureNumber: Number to write above the left end, or `nil`.
  ///   - scrolls: Whether the music keeps a fixed spacing and scrolls.
  ///   - focusColumn: The column to hold at the cursor anchor.
  public init(
    noteGroups: [[Pitch]],
    states: [ItemState],
    staffSpace: CGFloat = 16,
    durations: [Duration] = [],
    timeSignature: TimeSignature? = nil,
    key: KeySignature = .c,
    barlinesAfter: Set<Int> = [],
    showsFinalBarline: Bool = false,
    measureNumber: Int? = nil,
    scrolls: Bool = false,
    focusColumn: Double = 0
  ) {
    self.noteGroups = noteGroups
    self.states = states
    self.staffSpace = staffSpace
    self.durations = durations
    self.timeSignature = timeSignature
    self.key = key
    self.barlinesAfter = barlinesAfter
    self.showsFinalBarline = showsFinalBarline
    self.measureNumber = measureNumber
    self.scrolls = scrolls
    self.focusColumn = focusColumn
  }

  /// What SwiftUI interpolates when the cursor moves, so the system glides
  /// between notes instead of jumping.
  public var animatableData: Double {
    get { focusColumn }
    set { focusColumn = newValue }
  }

  /// Room the clefs and signatures take before the first note.
  private var preambleWidth: CGFloat {
    CGFloat(key.accidentalCount) * staffSpace * 0.9
      + (timeSignature == nil ? 0 : staffSpace * 2.2)
  }

  /// The across-the-page maths, shared with the notes and the bar lines.
  private func layout(width: CGFloat) -> StaffLayout {
    StaffLayout(
      staffSpace: staffSpace, width: width, columnCount: noteGroups.count,
      preamble: preambleWidth, scrolls: scrolls, durations: durations)
  }

  /// Headroom kept above and below for ledger lines.
  private var margin: CGFloat { staffSpace * 3 }

  /// Height of one five-line staff.
  private var staffHeight: CGFloat { staffSpace * 4 }

  /// Bottom line of the treble staff.
  private var trebleBottomLineY: CGFloat { margin + staffHeight }

  /// Bottom line of the bass staff.
  ///
  /// Six staff spaces below the treble bottom line: that is exactly the
  /// distance that lands middle C on one shared point between the two.
  private var bassBottomLineY: CGFloat { trebleBottomLineY + staffSpace * 6 }

  private var totalHeight: CGFloat { bassBottomLineY + margin }

  private func geometry(for clef: Clef) -> StaffGeometry {
    StaffGeometry(
      staffSpace: staffSpace,
      bottomLineY: clef == .treble ? trebleBottomLineY : bassBottomLineY)
  }

  /// The grand staff.
  public var body: some View {
    Canvas { context, size in
      drawCursorBand(in: context, size: size)
      drawStaffLines(in: context, width: size.width)
      drawBrace(in: context)
      drawBarlines(in: context, size: size)
      drawGlyphs(in: context, size: size)
    }
    .frame(height: totalHeight)
    .overlay(alignment: .topLeading) { measureBadge }
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

  private func drawStaffLines(in context: GraphicsContext, width: CGFloat) {
    for clef in [Clef.treble, .bass] {
      let staff = geometry(for: clef)
      for line in 0...4 {
        var path = Path()
        let lineY = staff.y(for: line * 2)
        path.move(to: CGPoint(x: 0, y: lineY))
        path.addLine(to: CGPoint(x: width, y: lineY))
        context.stroke(path, with: .color(.primary.opacity(0.55)), lineWidth: 1)
      }
    }
  }

  /// The vertical line joining the two staves into one system.
  private func drawBrace(in context: GraphicsContext) {
    var path = Path()
    path.move(to: CGPoint(x: 0.5, y: geometry(for: .treble).y(for: 8)))
    path.addLine(to: CGPoint(x: 0.5, y: geometry(for: .bass).y(for: 0)))
    context.stroke(path, with: .color(.primary.opacity(0.55)), lineWidth: 2)
  }

  /// A soft band behind the column the cursor is on, so where you are is never
  /// something to hunt for.
  private func drawCursorBand(in context: GraphicsContext, size: CGSize) {
    guard scrolls, !noteGroups.isEmpty else { return }

    let layout = layout(width: size.width)
    let column = Int(focusColumn.rounded())
    guard column < noteGroups.count else { return }

    let left =
      layout.noteAreaStart + layout.start(ofColumn: column)
      - layout.offset(focusing: focusColumn)
    let band = CGRect(
      x: left, y: margin - staffSpace,
      width: layout.width(ofColumn: column),
      height: bassBottomLineY - margin + staffSpace * 2)

    guard band.maxX > layout.noteAreaStart else { return }

    context.fill(
      Path(roundedRect: band, cornerRadius: staffSpace * 0.4),
      with: .color(ItemState.current.color.opacity(0.10)))
  }

  /// Bar lines, drawn through both staves so they read as one system.
  private func drawBarlines(in context: GraphicsContext, size: CGSize) {
    guard !barlinesAfter.isEmpty || showsFinalBarline else { return }

    let layout = layout(width: size.width)
    let shift = layout.offset(focusing: focusColumn)
    let visible = layout.noteAreaStart...(layout.noteAreaStart + layout.noteAreaWidth)
    let top = geometry(for: .treble).y(for: 8)
    let bottom = geometry(for: .bass).y(for: 0)

    func line(at positionX: CGFloat, thick: Bool) {
      guard visible.contains(positionX) else { return }
      var path = Path()
      path.move(to: CGPoint(x: positionX, y: top))
      path.addLine(to: CGPoint(x: positionX, y: bottom))
      context.stroke(
        path, with: .color(.primary.opacity(0.55)), lineWidth: thick ? 3 : 1)
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

  /// The key and time signatures, written once for both staves.
  private func drawPreamble(
    in cgContext: CGContext, startX: CGFloat, font: CTFont, canvasHeight: CGFloat
  ) {
    let ink = PlatformColor.staffInk(colorScheme)

    for clef in [Clef.treble, .bass] {
      var cursor = startX
      let staff = geometry(for: clef)
      let steps = StaffView.accidentalSteps(for: key, clef: clef)
      let glyph = key.usesSharps ? Bravura.Glyph.sharp : Bravura.Glyph.flat

      for index in 0..<key.accidentalCount where index < steps.count {
        draw(
          glyph, at: CGPoint(x: cursor, y: staff.y(for: steps[index])),
          color: ink, font: font, in: cgContext, canvasHeight: canvasHeight, centered: false)
        cursor += staffSpace * 0.9
      }

      guard let time = timeSignature else { continue }
      let lower = Int((4 / time.beatValue.beats).rounded())
      for (digit, step) in [(time.beatsPerBar, 5), (lower, 1)] {
        draw(
          Bravura.Glyph.timeSignatureDigit(digit),
          at: CGPoint(x: cursor + staffSpace * 0.4, y: staff.y(for: step)),
          color: ink, font: font, in: cgContext, canvasHeight: canvasHeight, centered: false)
      }
    }
  }

  private func drawGlyphs(in context: GraphicsContext, size: CGSize) {
    let font = Bravura.font(staffSpace: staffSpace)
    let layout = layout(width: size.width)
    let shift = layout.offset(focusing: focusColumn)
    let clefX = staffSpace * 0.8
    let firstNoteX = layout.noteAreaStart

    context.withCGContext { cgContext in
      draw(
        Bravura.Glyph.trebleClef,
        at: CGPoint(x: clefX, y: geometry(for: .treble).y(for: 2)),
        color: PlatformColor.staffInk(colorScheme),
        font: font, in: cgContext, canvasHeight: size.height, centered: false)

      draw(
        Bravura.Glyph.bassClef,
        at: CGPoint(x: clefX, y: geometry(for: .bass).y(for: 6)),
        color: PlatformColor.staffInk(colorScheme),
        font: font, in: cgContext, canvasHeight: size.height, centered: false)

      drawPreamble(
        in: cgContext, startX: clefX + staffSpace * 3.6,
        font: font, canvasHeight: size.height)

      // Clipped to the note area so the music slides under the clefs.
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

        if group.isEmpty {
          let value = durations.indices.contains(index) ? durations[index].value : .quarter
          draw(
            Bravura.Glyph.rest(for: value),
            at: CGPoint(x: noteX, y: geometry(for: .treble).y(for: 4)),
            color: PlatformColor.ink(for: state, in: colorScheme),
            font: font, in: cgContext, canvasHeight: size.height, centered: true)
          continue
        }

        for pitch in group.sorted(by: { $0.midiNoteNumber < $1.midiNoteNumber }) {
          drawNote(
            pitch, state: state,
            duration: durations.indices.contains(index) ? durations[index] : nil,
            at: noteX, font: font, in: cgContext, canvasHeight: size.height)
        }
      }

      cgContext.restoreGState()
    }
  }

  private func drawNote(
    _ pitch: Pitch,
    state: ItemState,
    duration: Duration?,
    at noteX: CGFloat,
    font: CTFont,
    in cgContext: CGContext,
    canvasHeight: CGFloat
  ) {
    let clef = pitch.grandStaffClef
    let staff = geometry(for: clef)
    let step = pitch.staffStep(in: clef)
    let baseline = staff.y(for: step)
    let color = PlatformColor.ink(for: state, in: colorScheme)

    drawLedgerLines(for: step, at: noteX, staff: staff, in: cgContext, color: color)

    if pitch.requiresSharp {
      draw(
        Bravura.Glyph.sharp,
        at: CGPoint(x: noteX - staffSpace * 1.6, y: baseline),
        color: color, font: font, in: cgContext, canvasHeight: canvasHeight, centered: true)
    }

    draw(
      Bravura.Glyph.noteheadBlack,
      at: CGPoint(x: noteX, y: baseline),
      color: color, font: font, in: cgContext, canvasHeight: canvasHeight, centered: true)
  }

  private func drawLedgerLines(
    for step: Int,
    at noteX: CGFloat,
    staff: StaffGeometry,
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
      let ledgerY = staff.y(for: ledger)
      cgContext.move(to: CGPoint(x: noteX - width / 2, y: ledgerY))
      cgContext.addLine(to: CGPoint(x: noteX + width / 2, y: ledgerY))
    }
    cgContext.strokePath()
    cgContext.restoreGState()
  }

  /// Draws a glyph with its baseline at `point.y`.
  ///
  /// Core Text draws upwards from the baseline while the canvas measures
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
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
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
