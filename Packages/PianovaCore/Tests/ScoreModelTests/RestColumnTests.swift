import Testing

@testable import ScoreModel

/// A bar of two crotchets and a minim rest.
private let withARest = Score(
  title: "Com pausa", composer: "—",
  rightHand: Part(
    clef: .treble,
    measures: [
      Measure([
        ScoreNote(Pitch(60), .quarter), ScoreNote(Pitch(62), .quarter),
        .rest(.half),
      ])
    ]))

// MARK: - Rule 35: a silence is written, not left as a gap

/// Rule 35 — the rest is a column of its own on the page.
///
/// It was not, and the symptom was visible: the counter read 25 events for a
/// piece with 26 written, and the last bar looked like it simply ended early.
@Test func aRestIsDrawnAsAColumn() {
  #expect(withARest.columns.count == 3)

  // Indexed through `last` rather than a literal: a test that traps on a
  // missing element takes the whole suite down with it and hides every other
  // result, which is worse than the bug it was meant to catch.
  guard let rest = withARest.columns.last else {
    Issue.record("a peça não tem coluna nenhuma")
    return
  }

  #expect(rest.isRest)
  #expect(rest.pitches.isEmpty)
}

/// Rule 35 — and it keeps the width its duration deserves.
@Test func aRestKeepsItsDuration() {
  #expect(withARest.columns.last?.duration.beats == 2)
}

/// The engine is never asked to strike a silence.
@Test func theEngineIsNeverAskedToPlayARest() {
  #expect(withARest.onsets.count == 2)
  #expect(withARest.onsets.allSatisfy { !$0.pitches.isEmpty })
}

/// The page and the engine are kept in step by an explicit mapping.
@Test func soundingColumnsMapThePageToTheEngine() {
  #expect(withARest.soundingColumns == [0, 1])
  #expect(withARest.soundingColumns.count == withARest.onsets.count)
}

/// Every sounding column really does sound, and every rest is left out.
@Test func theMappingAgreesWithTheColumnsItPointsAt() {
  for score in [withARest, oneWholeBarOfRest, twoHandedWithRest] {
    for index in score.soundingColumns {
      #expect(
        score.columns.indices.contains(index),
        "\(score.title): o mapa aponta para fora da página")
      #expect(
        score.columns.indices.contains(index) && !score.columns[index].isRest,
        "\(score.title): aponta para uma pausa")
    }
    #expect(
      score.soundingColumns.count == score.onsets.count,
      "\(score.title): o mapa e os eventos discordam")
  }
}

/// A bar that is entirely silent still occupies its bar.
private let oneWholeBarOfRest = Score(
  title: "Compasso em silêncio", composer: "—",
  rightHand: Part(
    clef: .treble,
    measures: [
      Measure([ScoreNote(Pitch(60), .whole)]),
      Measure([.rest(.whole)]),
      Measure([ScoreNote(Pitch(62), .whole)]),
    ]))

/// A silent bar is drawn, and the piece does not appear to skip it.
@Test func aSilentBarIsStillOnThePage() {
  #expect(oneWholeBarOfRest.columns.count == 3)
  #expect(oneWholeBarOfRest.columns.dropFirst().first?.isRest == true)
  #expect(oneWholeBarOfRest.onsets.count == 2)
  #expect(oneWholeBarOfRest.soundingColumns == [0, 2])
}

/// A rest in one hand while the other plays is not a rest on the page.
private let twoHandedWithRest = Score(
  title: "Uma mão descansa", composer: "—",
  rightHand: Part(
    clef: .treble,
    measures: [Measure([ScoreNote(Pitch(60), .half), ScoreNote(Pitch(64), .half)])]),
  leftHand: Part(
    clef: .bass,
    measures: [Measure([.rest(.half), ScoreNote(Pitch(48), .half)])]))

/// Where one hand rests and the other plays, the column sounds.
@Test func aColumnSoundsIfEitherHandPlays() {
  #expect(twoHandedWithRest.columns.count == 2)
  #expect(twoHandedWithRest.columns.allSatisfy { !$0.isRest })
  #expect(twoHandedWithRest.columns.last?.pitches.count == 2, "as duas mãos entram juntas")
}

/// Bar lines are counted over the written page, silences included.
///
/// Counting them over the sounding events alone put the line in the wrong place
/// the moment a bar ended in silence.
@Test func barLinesAreCountedOverTheWrittenPage() {
  #expect(oneWholeBarOfRest.barlineColumns == [0, 1])
}

/// The columns run in time order, with no two at the same moment.
@Test func columnsAreOrderedAndDistinct() {
  for score in Songs.allScoresForTesting {
    let times = score.columns.map(\.beats)
    #expect(times == times.sorted(), "\(score.title): colunas fora de ordem")
    #expect(Set(times).count == times.count, "\(score.title): duas colunas no mesmo instante")
  }
}

/// Test fixtures, kept here so `ScoreModel` needs nothing from `Course`.
private enum Songs {
  static let allScoresForTesting: [Score] = [withARest, oneWholeBarOfRest, twoHandedWithRest]
}
