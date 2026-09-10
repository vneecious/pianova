import CoreGraphics
import Testing

@testable import ScoreModel

/// Sixteen equal columns with a bar line after every fourth.
private let equalWidths = Array(repeating: CGFloat(25), count: 16)
private let everyFourBars: Set<Int> = [3, 7, 11, 15]

// MARK: - Rule 68: the piece is broken up

/// Rule 68 — a piece wider than the page becomes several systems.
@Test func aLongPieceBecomesSeveralSystems() {
  let systems = SystemLayout.systems(
    widths: equalWidths, barlinesAfter: everyFourBars, available: 200)

  #expect(systems.count > 1)
}

/// Rule 68 — every column lands in exactly one system, in order.
@Test func everyColumnLandsInExactlyOneSystem() {
  let systems = SystemLayout.systems(
    widths: equalWidths, barlinesAfter: everyFourBars, available: 200)

  #expect(systems.flatMap { Array($0) } == Array(0..<16))
}

/// A piece that already fits stays as one system.
@Test func aShortPieceStaysOnOneLine() {
  let systems = SystemLayout.systems(
    widths: equalWidths, barlinesAfter: everyFourBars, available: 10_000)

  #expect(systems == [0..<16])
}

/// Nothing to lay out yields nothing.
@Test func anEmptyPieceHasNoSystems() {
  #expect(SystemLayout.systems(widths: [], barlinesAfter: [], available: 500).isEmpty)
}

// MARK: - Rule 69: breaks land on bar lines

/// Rule 69 — a system ends where a bar ends.
///
/// Not a stylistic preference: a bar split across two lines cannot be counted,
/// which is the one thing a beginner is there to do.
@Test func systemsEndOnBarLines() {
  let systems = SystemLayout.systems(
    widths: equalWidths, barlinesAfter: everyFourBars, available: 200)

  for system in systems.dropLast() {
    #expect(
      everyFourBars.contains(system.upperBound - 1),
      "sistema termina em \(system.upperBound - 1), que não é fim de compasso")
  }
}

/// Two bars of four fit a line of eight columns, and the break is between them.
@Test func aLineTakesWholeBars() {
  let systems = SystemLayout.systems(
    widths: equalWidths, barlinesAfter: everyFourBars, available: 8 * 25)

  #expect(systems == [0..<8, 8..<16])
}

/// With no bar lines at all it still fills lines rather than looping forever.
@Test func musicWithoutBarLinesStillBreaks() {
  let systems = SystemLayout.systems(
    widths: equalWidths, barlinesAfter: [], available: 200)

  #expect(systems.flatMap { Array($0) } == Array(0..<16))
  #expect(systems.allSatisfy { !$0.isEmpty })
}

// MARK: - Progress is always made

/// A column wider than the whole line still gets a system of its own.
///
/// Otherwise the layout would never advance and the app would hang.
@Test func anOversizedColumnStillFits() {
  let systems = SystemLayout.systems(
    widths: [500, 25, 25], barlinesAfter: [], available: 100)

  #expect(systems.first == 0..<1)
  #expect(systems.flatMap { Array($0) } == [0, 1, 2])
}

/// No system is ever empty, whatever the widths.
@Test func noSystemIsEmpty() {
  for available in [1, 10, 60, 200, 1000].map(CGFloat.init) {
    let systems = SystemLayout.systems(
      widths: equalWidths, barlinesAfter: everyFourBars, available: available)

    #expect(systems.allSatisfy { !$0.isEmpty }, "largura \(available) produziu sistema vazio")
    #expect(systems.flatMap { Array($0) } == Array(0..<16), "largura \(available) perdeu colunas")
  }
}

/// A useless width degrades to one system rather than to a hang.
@Test func aZeroWidthDoesNotLoop() {
  #expect(
    SystemLayout.systems(widths: equalWidths, barlinesAfter: everyFourBars, available: 0)
      == [0..<16])
}

/// Mixed widths still respect the line, within one column's slack.
@Test func mixedWidthsRespectTheLine() {
  let widths: [CGFloat] = [100, 25, 25, 50, 100, 25, 25, 50]
  let bars: Set<Int> = [3, 7]

  let systems = SystemLayout.systems(widths: widths, barlinesAfter: bars, available: 200)

  #expect(systems == [0..<4, 4..<8])
}

// MARK: - A linha-guia dentro de um sistema

/// A guide line in a later system is reported in that system's own columns.
///
/// Each system draws itself and knows nothing about the ones around it, so the
/// position has to be translated or the line lands in the wrong place.
@Test func thePlayheadIsTranslatedIntoTheSystem() {
  let position = PlayheadPosition(column: 9, progress: 0.5)

  let local = position.within(8..<16)
  #expect(local?.column == 1, "coluna 9 é a segunda de um sistema que começa em 8")
  #expect(local?.progress == 0.5, "a fração não muda ao trocar de sistema")
}

/// A system the line has not reached, or has already left, draws none.
@Test func aSystemWithoutTheLineDrawsNone() {
  let position = PlayheadPosition(column: 9, progress: 0.25)

  #expect(position.within(0..<8) == nil, "o sistema anterior não deveria mostrar a linha")
  #expect(position.within(16..<24) == nil, "nem o seguinte")
}

/// The first column of the first system needs no translating.
@Test func theFirstColumnStaysWhereItIs() {
  #expect(PlayheadPosition(column: 0, progress: 0).within(0..<8)?.column == 0)
}
