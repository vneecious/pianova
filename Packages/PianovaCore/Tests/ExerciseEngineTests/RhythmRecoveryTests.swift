import ScoreModel
import Testing

@testable import ExerciseEngine

/// Eight crotchets at 60bpm: two bars of 4/4, one note per second.
private func eightQuarters() -> RhythmSession {
  RhythmSession(
    notes: [60, 62, 64, 65, 67, 65, 64, 62].map { RhythmicNote(Pitch(UInt8($0)), .quarter) },
    tempo: 60)
}

// MARK: - Rule 42: back to the start of the bar

/// Rule 42 — notes are grouped into bars by their written onset.
@Test func notesFallIntoBarsByTheirOnset() {
  let session = eightQuarters()

  #expect(session.bar(of: 0, beatsPerBar: 4) == 0)
  #expect(session.bar(of: 3, beatsPerBar: 4) == 0)
  #expect(session.bar(of: 4, beatsPerBar: 4) == 1)
  #expect(session.bar(of: 7, beatsPerBar: 4) == 1)
}

/// Rule 42 — a mistake sends you to the first note of its own bar.
@Test func aMistakeGoesBackToTheStartOfItsBar() {
  let session = eightQuarters()

  #expect(session.firstNote(ofBarContaining: 2, beatsPerBar: 4) == 0)
  #expect(session.firstNote(ofBarContaining: 6, beatsPerBar: 4) == 4)
}

/// Rule 42 — and not to the beginning of the piece.
@Test func aMistakeInTheSecondBarDoesNotRestartThePiece() {
  let session = eightQuarters()

  #expect(session.firstNote(ofBarContaining: 5, beatsPerBar: 4) != 0)
}

/// A bar of three groups by three, not by four.
@Test func barsFollowTheTimeSignatureGiven() {
  let session = eightQuarters()

  #expect(session.bar(of: 3, beatsPerBar: 3) == 1)
  #expect(session.firstNote(ofBarContaining: 4, beatsPerBar: 3) == 3)
}

// MARK: - Rules 42 and 44: what rewinding keeps

/// Rewinding moves the cursor back to the note asked for.
@Test func rewindingMovesTheCursorBack() {
  var session = eightQuarters()

  _ = session.press([Pitch(60)], at: 0)
  _ = session.press([Pitch(62)], at: 1)
  #expect(session.index == 2)

  session.rewind(to: 0)
  #expect(session.index == 0)
}

/// Rule 44 — verdicts earned before the retaken bar survive it.
@Test func rewindingKeepsWhatWentRightBefore() {
  var session = eightQuarters()

  for (offset, note) in [60, 62, 64, 65, 67].enumerated() {
    _ = session.press([Pitch(UInt8(note))], at: Double(offset))
  }
  #expect(session.outcome(of: 0) == .onTime)

  // A mistake in the second bar sends us to note 4, and the first bar stands.
  session.rewind(to: 4)

  #expect(session.outcome(of: 0) == .onTime)
  #expect(session.outcome(of: 3) == .onTime)
  #expect(session.outcome(of: 4) == nil, "o compasso refeito deveria voltar a ser julgado")
}

/// Rewinding forgets everything from the landing note onwards.
@Test func rewindingClearsTheBarBeingRetaken() {
  var session = eightQuarters()

  for (offset, note) in [60, 62, 64, 65].enumerated() {
    _ = session.press([Pitch(UInt8(note))], at: Double(offset))
  }

  session.rewind(to: 1)

  #expect(session.outcome(of: 0) == .onTime)
  for index in 1...3 {
    #expect(session.outcome(of: index) == nil, "a nota \(index) deveria ter sido esquecida")
  }
}

/// Rewinding is clamped, so a bad index cannot corrupt the run.
@Test func rewindingIsClamped() {
  var session = eightQuarters()

  session.rewind(to: -4)
  #expect(session.index == 0)

  session.rewind(to: 99)
  #expect(session.index == session.notes.count)
  #expect(session.isFinished)
}

/// After rewinding, the run can be replayed from the landing note.
@Test func theRunResumesFromTheLandingNote() {
  var session = eightQuarters()

  for (offset, note) in [60, 62, 64, 65].enumerated() {
    _ = session.press([Pitch(UInt8(note))], at: Double(offset))
  }
  session.rewind(to: 0)

  // Replaying the bar from its written moments works exactly as the first time.
  for (offset, note) in [60, 62, 64, 65].enumerated() {
    let judgement = session.press([Pitch(UInt8(note))], at: Double(offset))
    #expect(judgement.verdict == .onTime, "a nota \(note) deveria valer na retomada")
  }
  #expect(session.index == 4)
}
