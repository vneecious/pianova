import ScoreModel
import Testing

@testable import NoteQuiz

private let nameMiddleC = NoteCard(pitch: Pitch(60), clef: .treble)
private let placeMiddleC = NoteCard(pitch: Pitch(60), clef: .treble, direction: .placeTheNote)

/// A card defaults to asking for the note's name.
@Test func cardsDefaultToNamingDirection() {
  #expect(nameMiddleC.direction == .nameTheNote)
}

/// A naming card is solved by the right letter.
@Test func namingCardAcceptsItsLetter() {
  #expect(nameMiddleC.accepts(.letter(.c)))
  #expect(nameMiddleC.accepts(.letter(.d)) == false)
}

/// A naming card is not solved by pointing at the staff.
@Test func namingCardRejectsAPosition() {
  #expect(nameMiddleC.accepts(.staffStep(-2)) == false)
}

/// README › Cards invertidos — rule 11: a reversed card is solved by pointing
/// at the right place on the staff.
@Test func placementCardAcceptsItsStaffStep() {
  #expect(placeMiddleC.accepts(.staffStep(-2)))
  #expect(placeMiddleC.accepts(.staffStep(0)) == false)
}

/// A placement card is not solved by naming the note.
@Test func placementCardRejectsALetter() {
  #expect(placeMiddleC.accepts(.letter(.c)) == false)
}

/// README › Cards invertidos — rule 13: the octave matters, so another C on the
/// same staff is a wrong answer.
@Test func placementCardRejectsTheSameLetterInAnotherOctave() {
  let c5Step = Pitch(72).staffStep(in: .treble)

  #expect(placeMiddleC.accepts(.staffStep(c5Step)) == false)
}

/// The same pitch sits at different steps in different clefs.
@Test func placementCardUsesItsOwnClef() {
  let inBass = NoteCard(pitch: Pitch(60), clef: .bass, direction: .placeTheNote)

  #expect(inBass.accepts(.staffStep(10)))
  #expect(inBass.accepts(.staffStep(-2)) == false)
}

/// The expected answer matches the direction the card was asked in.
@Test func expectedAnswerFollowsTheDirection() {
  #expect(nameMiddleC.expectedAnswer == .letter(.c))
  #expect(placeMiddleC.expectedAnswer == .staffStep(-2))
}

/// Flipping a card keeps its pitch and clef.
@Test func flippingACardKeepsPitchAndClef() {
  let flipped = nameMiddleC.asking(.placeTheNote)

  #expect(flipped.pitch == nameMiddleC.pitch)
  #expect(flipped.clef == nameMiddleC.clef)
  #expect(flipped.direction == .placeTheNote)
}

/// An accidental does not change the position, so a sharp is placed on the
/// natural's line.
@Test func sharpsArePlacedOnTheNaturalStep() {
  let cSharp = NoteCard(pitch: Pitch(61), clef: .treble, direction: .placeTheNote)

  #expect(cSharp.accepts(.staffStep(-2)))
}

/// A heard card is answered by name, like a written one.
@Test func aHeardCardIsAnsweredByName() {
  let heard = NoteCard(pitch: Pitch(60), clef: .treble, direction: .hearTheNote)

  #expect(heard.accepts(.letter(.c)))
  #expect(heard.accepts(.letter(.d)) == false)
  #expect(heard.expectedAnswer == .letter(.c))
}

/// A heard card is not answered by pointing at the staff: nothing is written.
@Test func aHeardCardRejectsAPosition() {
  let heard = NoteCard(pitch: Pitch(60), clef: .treble, direction: .hearTheNote)

  #expect(heard.accepts(.staffStep(-2)) == false)
}

/// Hearing a sharp still answers by the letter below it.
@Test func aHeardSharpIsNamedByItsLetter() {
  let heard = NoteCard(pitch: Pitch(61), clef: .treble, direction: .hearTheNote)

  #expect(heard.accepts(.letter(.c)))
}
