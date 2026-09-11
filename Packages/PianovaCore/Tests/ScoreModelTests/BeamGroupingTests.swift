import Testing

@testable import ScoreModel

/// Builds a run of events starting at zero, each following the last.
private func run(_ items: [(NoteValue, Bool)]) -> [BeamGrouping.Note] {
  var time = 0.0
  return items.map { value, isRest in
    let note = BeamGrouping.Note(start: time, duration: Duration(value), isRest: isRest)
    time += value.beats
    return note
  }
}

private func quavers(_ count: Int) -> [BeamGrouping.Note] {
  run(Array(repeating: (NoteValue.eighth, false), count: count))
}

// MARK: - Rule 84: what belongs to a beat is beamed

/// Rule 84 — two quavers in one beat are joined.
@Test func twoQuaversInABeatAreBeamed() {
  #expect(BeamGrouping.groups(notes: quavers(2), time: .fourFour) == [0..<2])
}

/// Rule 84 — four quavers in 4/4 are two beats, so two beams.
///
/// One beam over all four would say "this is one thing", and it is two.
@Test func fourQuaversAreTwoBeams() {
  #expect(BeamGrouping.groups(notes: quavers(4), time: .fourFour) == [0..<2, 2..<4])
}

/// Rule 88 — a group never crosses a bar line.
@Test func aBeamNeverCrossesTheBar() {
  let groups = BeamGrouping.groups(notes: quavers(8), time: .fourFour)

  #expect(groups == [0..<2, 2..<4, 4..<6, 6..<8])
  #expect(groups.allSatisfy { $0.count == 2 })
}

/// Semiquavers group four to a beat, since four of them make one crotchet.
@Test func semiquaversGroupFourToABeat() {
  let notes = run(Array(repeating: (NoteValue.sixteenth, false), count: 8))

  #expect(BeamGrouping.groups(notes: notes, time: .fourFour) == [0..<4, 4..<8])
}

// MARK: - Rule 85: a lone note keeps its flag

/// Rule 85 — one quaver alone in its beat is not beamed.
@Test func aLoneQuaverKeepsItsFlag() {
  let notes = run([(.eighth, false), (.quarter, false), (.eighth, false)])

  #expect(BeamGrouping.groups(notes: notes, time: .fourFour).isEmpty)
}

/// Crotchets and longer never beam at all.
@Test func longFiguresNeverBeam() {
  let notes = run([(.quarter, false), (.quarter, false), (.half, false)])

  #expect(BeamGrouping.groups(notes: notes, time: .fourFour).isEmpty)
}

// MARK: - Rule 86: a rest breaks the group

/// Rule 86 — a beam does not span a silence.
@Test func aRestBreaksTheBeam() {
  let notes = run([(.eighth, false), (.eighth, true), (.eighth, false), (.eighth, false)])

  #expect(BeamGrouping.groups(notes: notes, time: .fourFour) == [2..<4])
}

/// A rest between two lone quavers leaves neither beamed.
@Test func aRestCanLeaveNothingToBeam() {
  let notes = run([(.eighth, false), (.eighth, true), (.eighth, true), (.eighth, false)])

  #expect(BeamGrouping.groups(notes: notes, time: .fourFour).isEmpty)
}

// MARK: - Rule 87: compound time groups in threes

/// Rule 87 — six quavers in 6/8 are two groups of three.
///
/// Grouping them in twos would say the bar has three beats. It has two, each a
/// dotted crotchet, and the beams are how anyone can see that.
@Test func compoundTimeGroupsInThrees() {
  let sixEight = TimeSignature(beatsPerBar: 6, beatValue: .eighth)

  #expect(BeamGrouping.groups(notes: quavers(6), time: sixEight) == [0..<3, 3..<6])
}

/// The group length follows the meter, not a fixed number.
@Test func theGroupLengthFollowsTheMeter() {
  #expect(BeamGrouping.groupLength(for: .fourFour) == 1)
  #expect(BeamGrouping.groupLength(for: .threeFour) == 1)
  #expect(BeamGrouping.groupLength(for: TimeSignature(beatsPerBar: 6, beatValue: .eighth)) == 1.5)
  #expect(BeamGrouping.groupLength(for: TimeSignature(beatsPerBar: 9, beatValue: .eighth)) == 1.5)
}

/// 2/8 is simple time despite the quaver beat, so it does not group in threes.
@Test func twoEightIsNotCompound() {
  #expect(BeamGrouping.groupLength(for: TimeSignature(beatsPerBar: 2, beatValue: .eighth)) == 0.5)
}

// MARK: - Whole pieces

/// A piece with an upbeat still groups against its own bar lines.
@Test func anUpbeatDoesNotShiftTheGroups() {
  let score = Score(
    title: "Anacruse", composer: "—",
    timeSignature: .fourFour,
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([ScoreNote(Pitch(67), .eighth), ScoreNote(Pitch(67), .eighth)]),
        Measure(Array(repeating: ScoreNote(Pitch(60), .eighth), count: 8)),
      ]),
    hasPickup: true)

  let groups = score.beamGroups

  #expect(groups.first == 0..<2, "a própria anacruse é um grupo")
  #expect(groups.count == 5, "mais quatro tempos no compasso cheio")
}

/// Every group holds at least two notes, whatever the piece.
@Test func noGroupIsEverASingleNote() {
  for score in [Songs.alvorada, Songs.londonBridge] {
    for group in score.beamGroups {
      #expect(group.count >= 2, "\(score.title) tem uma barra sobre uma nota só")
    }
  }
}

/// Fixtures kept local so `ScoreModel` needs nothing from `Course`.
private enum Songs {
  static let alvorada = Score(
    title: "Alvorada", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(Pitch(60), .eighth), ScoreNote(Pitch(64), .eighth),
          ScoreNote(Pitch(60), .eighth), ScoreNote(Pitch(64), .eighth),
          ScoreNote(Pitch(60), .quarter), ScoreNote(Pitch(64), .quarter),
        ])
      ]))

  static let londonBridge = Score(
    title: "London Bridge", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(Pitch(67), .quarter), ScoreNote(Pitch(69), .eighth),
          ScoreNote(Pitch(67), .eighth), ScoreNote(Pitch(65), .quarter),
          ScoreNote(Pitch(64), .quarter),
        ])
      ]))
}
