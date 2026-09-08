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
public struct StaffView: View {
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
    self.onTapStep = onTapStep
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
        drawStaffLines(in: context, width: size.width, bottomLineY: bottomLineY)
        drawTargets(in: context, width: size.width)
        drawGlyphs(in: context, size: size, bottomLineY: bottomLineY)
      }
      .contentShape(Rectangle())
      .onTapGesture(coordinateSpace: .local) { location in
        handleTap(at: location, width: proxy.size.width)
      }
    }
    .frame(height: staffHeight + margin * 2)
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

  private func drawStaffLines(in context: GraphicsContext, width: CGFloat, bottomLineY: CGFloat) {
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
    let layout = StaffLayout(
      staffSpace: staffSpace, width: size.width, columnCount: noteGroups.count)
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

      for (index, group) in noteGroups.enumerated() {
        let state = index < states.count ? states[index] : .pending
        let noteX = firstNoteX + spacing * (CGFloat(index) + 0.5)
        for pitch in group.sorted(by: { $0.midiNoteNumber < $1.midiNoteNumber }) {
          drawNote(
            pitch, state: state,
            duration: durations.indices.contains(index) ? durations[index] : nil,
            at: noteX, bottomLineY: bottomLineY,
            font: font, in: cgContext, canvasHeight: size.height)
        }
      }

      drawMarks(
        in: cgContext, firstNoteX: firstNoteX, available: available,
        bottomLineY: bottomLineY, font: font, canvasHeight: size.height)
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
