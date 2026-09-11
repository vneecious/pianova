import CoreGraphics
import Testing

@testable import ScoreModel

/// *Au Clair de la Lune* as the course writes it: three bars of movement and a
/// closing semibreve.
private let auClair = Score(
  title: "Au Clair", composer: "—",
  rightHand: Part(
    clef: .treble,
    measures: [
      Measure([
        ScoreNote(Pitch(60), .quarter), ScoreNote(Pitch(60), .quarter),
        ScoreNote(Pitch(60), .quarter), ScoreNote(Pitch(62), .quarter),
      ]),
      Measure([ScoreNote(Pitch(64), .half), ScoreNote(Pitch(62), .half)]),
      Measure([
        ScoreNote(Pitch(60), .quarter), ScoreNote(Pitch(64), .quarter),
        ScoreNote(Pitch(62), .quarter), ScoreNote(Pitch(62), .quarter),
      ]),
      Measure([ScoreNote(Pitch(60), .whole)]),
    ]))

/// How the piece breaks at a given width, measured exactly as the sheet does.
private func systems(width: CGFloat, staffSpace: CGFloat = 16) -> [Range<Int>] {
  let layout = StaffLayout(
    staffSpace: staffSpace, width: width, columnCount: auClair.columns.count,
    scrolls: true, durations: auClair.columns.map(\.duration))

  return SystemLayout.systems(
    widths: (0..<auClair.columns.count).map { layout.width(ofColumn: $0) },
    barlinesAfter: auClair.barlineColumns,
    available: max(width - (layout.noteAreaStart + staffSpace * 4), staffSpace))
}

/// Eleven columns of a four-bar tune fit one line on any real screen.
///
/// The natural width is sixteen crotchets; nothing about that needs two
/// systems on a Mac window or an iPad, and breaking anyway leaves one lonely
/// semibreve on a line of its own.
@Test func aFourBarTuneFitsOneSystem() {
  for width in [CGFloat(1200), 1900, 2500] {
    #expect(systems(width: width) == [0..<11], "largura \(width) quebrou sem precisar")
  }
}

/// Narrow enough, it does break — and on a bar line.
@Test func aNarrowPageStillBreaksOnBars() {
  let broken = systems(width: 500)

  #expect(broken.count > 1)
  #expect(broken.flatMap { Array($0) } == Array(0..<11))
  for system in broken.dropLast() {
    #expect(
      auClair.barlineColumns.contains(system.upperBound - 1),
      "quebrou no meio de um compasso")
  }
}
