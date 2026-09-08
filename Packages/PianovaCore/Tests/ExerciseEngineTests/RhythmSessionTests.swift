import ScoreModel
import Testing

@testable import ExerciseEngine

/// Four quarter notes on middle C, at one beat per second.
private func fourQuarters() -> RhythmSession {
  RhythmSession(
    notes: (0..<4).map { _ in RhythmicNote(Pitch(60), .quarter) },
    tempo: 60)
}

/// At 60 bpm a beat lasts exactly one second.
@Test func aBeatAtSixtyIsOneSecond() {
  #expect(fourQuarters().beatDuration == 1)
  #expect(RhythmSession(notes: [], tempo: 120).beatDuration == 0.5)
}

/// A note begins where everything written before it ends.
@Test func onsetIsTheSumOfWhatComesBefore() {
  let session = fourQuarters()

  #expect(session.onset(of: 0) == 0)
  #expect(session.onset(of: 1) == 1)
  #expect(session.onset(of: 3) == 3)
}

/// Longer figures push the notes after them further out.
@Test func longerFiguresPushLaterOnsets() {
  let session = RhythmSession(
    notes: [
      RhythmicNote(Pitch(60), .half),
      RhythmicNote(Pitch(62), .quarter),
      RhythmicNote(Pitch(64), .quarter),
    ],
    tempo: 60)

  #expect(session.onset(of: 1) == 2)
  #expect(session.onset(of: 2) == 3)
  #expect(session.totalDuration == 4)
}

/// A dotted figure lasts half again as long, and the next note waits for it.
@Test func aDottedFigureDelaysWhatFollows() {
  let session = RhythmSession(
    notes: [
      RhythmicNote(Pitch(60), .half, dotted: true),
      RhythmicNote(Pitch(62), .quarter),
    ],
    tempo: 60)

  #expect(session.onset(of: 1) == 3)
  #expect(session.totalDuration == 4)
}

/// A press at the written moment is on time.
@Test func aPressOnTheBeatIsOnTime() {
  var session = fourQuarters()

  let judgement = session.press([Pitch(60)], at: 0)

  #expect(judgement.verdict == .onTime)
  #expect(judgement.offset == 0)
  #expect(session.index == 1)
}

/// A press inside the window still counts.
@Test func aPressInsideTheWindowCounts() {
  var session = fourQuarters()

  #expect(session.press([Pitch(60)], at: 0.2).verdict == .onTime)
  #expect(session.press([Pitch(60)], at: 0.8).verdict == .onTime)
  #expect(session.offBeatCount == 0)
}

/// Ahead of the window is early, behind it is late.
@Test func outsideTheWindowIsEarlyOrLate() {
  var session = fourQuarters()

  let first = session.press([Pitch(60)], at: 0)
  let early = session.press([Pitch(60)], at: 0.5)
  let late = session.press([Pitch(60)], at: 3.0)

  #expect(first.verdict == .onTime)
  #expect(early.verdict == .early)
  #expect(late.verdict == .late)
  #expect(session.offBeatCount == 2)
}

/// The offset says how far off, and which side.
@Test func theOffsetSaysHowFarOff() {
  var session = fourQuarters()
  _ = session.press([Pitch(60)], at: 0)

  let judgement = session.press([Pitch(60)], at: 1.4)

  #expect(judgement.offset > 0.39 && judgement.offset < 0.41)
  #expect(judgement.verdict == .late)
}

/// A faster tempo tightens the window, because the window is a share of a beat.
@Test func aFasterTempoTightensTheWindow() {
  let slow = RhythmSession(notes: [RhythmicNote(Pitch(60), .quarter)], tempo: 60)
  let fast = RhythmSession(notes: [RhythmicNote(Pitch(60), .quarter)], tempo: 120)

  #expect(fast.toleranceWindow < slow.toleranceWindow)
  #expect(fast.toleranceWindow == slow.toleranceWindow / 2)
}

/// The wrong key does not advance the run, however well timed.
@Test func theWrongKeyDoesNotAdvance() {
  var session = fourQuarters()

  let judgement = session.press([Pitch(62)], at: 0)

  #expect(judgement.verdict == .wrongNote)
  #expect(session.index == 0)
  #expect(session.wrongNoteCount == 1)
}

/// A chord needs every note of it, not just one.
@Test func aChordNeedsAllOfItsNotes() {
  var session = RhythmSession(
    notes: [RhythmicNote(pitches: [Pitch(60), Pitch(64)], duration: Duration(.quarter))],
    tempo: 60)

  #expect(session.press([Pitch(60)], at: 0).verdict == .wrongNote)
  #expect(session.press([Pitch(60), Pitch(64)], at: 0).verdict == .onTime)
}

/// The run reports when it is done.
@Test func theRunReportsWhenItIsDone() {
  var session = RhythmSession(notes: [RhythmicNote(Pitch(60), .quarter)], tempo: 60)

  let judgement = session.press([Pitch(60)], at: 0)

  #expect(judgement.isFinished)
  #expect(session.isFinished)
  #expect(session.currentNote == nil)
}

/// Pressing after the end is harmless.
@Test func pressingAfterTheEndIsHarmless() {
  var session = RhythmSession(notes: [], tempo: 60)

  #expect(session.press([Pitch(60)], at: 5).isFinished)
  #expect(session.wrongNoteCount == 0)
}

/// A silly tempo cannot produce a zero or negative beat.
@Test func aSillyTempoIsClamped() {
  #expect(RhythmSession(notes: [], tempo: 0).beatDuration == 60)
  #expect(RhythmSession(notes: [], tempo: -30).beatDuration == 60)
}

/// Before a note's window closes, nothing is abandoned.
@Test func nothingIsAbandonedBeforeItsWindowCloses() {
  var session = fourQuarters()

  #expect(session.advance(to: 0.2) == 0)
  #expect(session.index == 0)
  #expect(session.missedCount == 0)
}

/// Once the window has passed, the music moves on without the player.
@Test func theMusicMovesOnWithoutThePlayer() {
  var session = fourQuarters()

  let skipped = session.advance(to: 0.6)

  #expect(skipped == 1)
  #expect(session.index == 1)
  #expect(session.missedCount == 1)
}

/// Falling far behind abandons every note that went by.
@Test func fallingFarBehindAbandonsEveryNotePassed() {
  var session = fourQuarters()

  session.advance(to: 2.6)

  #expect(session.index == 3)
  #expect(session.missedCount == 3)
}

/// Advancing past the end stops at the end.
@Test func advancingPastTheEndStopsAtTheEnd() {
  var session = fourQuarters()

  session.advance(to: 99)

  #expect(session.isFinished)
  #expect(session.missedCount == 4)
  #expect(session.advance(to: 200) == 0)
}

/// Keeping up means nothing is missed.
@Test func keepingUpMissesNothing() {
  var session = fourQuarters()

  for beat in 0..<4 {
    session.advance(to: Double(beat))
    _ = session.press([Pitch(60)], at: Double(beat))
  }

  #expect(session.missedCount == 0)
  #expect(session.isFinished)
}

/// Nothing has an outcome before it is reached.
@Test func notesHaveNoOutcomeBeforeTheyAreReached() {
  let session = fourQuarters()

  #expect(session.outcomes.count == 4)
  #expect(session.outcomes.allSatisfy { $0 == nil })
}

/// A played note keeps the verdict it earned.
@Test func aPlayedNoteKeepsItsVerdict() {
  var session = fourQuarters()

  _ = session.press([Pitch(60)], at: 0)
  _ = session.press([Pitch(60)], at: 1.9)

  #expect(session.outcome(of: 0) == .onTime)
  #expect(session.outcome(of: 1) == .late)
  #expect(session.outcome(of: 2) == nil)
}

/// A note the music left behind is marked missed, not left blank.
@Test func anAbandonedNoteIsMarkedMissed() {
  var session = fourQuarters()

  session.advance(to: 1.6)

  #expect(session.outcome(of: 0) == .missed)
  #expect(session.outcome(of: 1) == .missed)
  #expect(session.outcome(of: 2) == nil)
}

/// A wrong key leaves the note unresolved: it has not gone by yet.
@Test func aWrongKeyLeavesTheNoteUnresolved() {
  var session = fourQuarters()

  _ = session.press([Pitch(62)], at: 0)

  #expect(session.outcome(of: 0) == nil)
}

/// Outcomes line up with the notes, one for one.
@Test func outcomesLineUpWithTheNotes() {
  var session = fourQuarters()

  for beat in 0..<4 {
    _ = session.press([Pitch(60)], at: Double(beat))
  }

  #expect(session.outcomes.compactMap { $0 }.count == session.notes.count)
}
