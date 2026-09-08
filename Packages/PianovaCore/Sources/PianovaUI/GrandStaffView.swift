import CoreText
import ScoreModel
import SwiftUI

/// The grand staff: treble above, bass below, joined at the left.
///
/// The two staves are placed so that middle C falls on the same point for both
/// — one ledger line under the treble staff and one over the bass staff. That
/// shared point is what makes a grand staff readable as a single system, and it
/// comes straight from ``Pitch/staffStep(in:)``, which the tests cover.
public struct GrandStaffView: View {
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

  /// Creates a grand staff.
  /// - Parameters:
  ///   - noteGroups: Groups of pitches, one column each, left to right.
  ///   - states: Visual state for each group, parallel to `noteGroups`.
  ///   - staffSpace: Distance between two staff lines, in points.
  public init(noteGroups: [[Pitch]], states: [ItemState], staffSpace: CGFloat = 16) {
    self.noteGroups = noteGroups
    self.states = states
    self.staffSpace = staffSpace
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
      drawStaffLines(in: context, width: size.width)
      drawBrace(in: context)
      drawGlyphs(in: context, size: size)
    }
    .frame(height: totalHeight)
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

  private func drawGlyphs(in context: GraphicsContext, size: CGSize) {
    let font = Bravura.font(staffSpace: staffSpace)
    let clefX = staffSpace * 0.8
    let firstNoteX = clefX + staffSpace * 4.5
    let available = max(size.width - firstNoteX - staffSpace * 2, staffSpace)
    let spacing = noteGroups.isEmpty ? 0 : available / CGFloat(noteGroups.count)

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

      for (index, group) in noteGroups.enumerated() {
        let state = index < states.count ? states[index] : .pending
        let noteX = firstNoteX + spacing * (CGFloat(index) + 0.5)

        for pitch in group.sorted(by: { $0.midiNoteNumber < $1.midiNoteNumber }) {
          drawNote(
            pitch, state: state, at: noteX,
            font: font, in: cgContext, canvasHeight: size.height)
        }
      }
    }
  }

  private func drawNote(
    _ pitch: Pitch,
    state: ItemState,
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
