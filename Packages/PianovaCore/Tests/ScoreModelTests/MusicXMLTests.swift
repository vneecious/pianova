import Foundation
import Testing

@testable import ScoreModel

/// A minimal but real MusicXML file: two bars of 3/4 in G, one of them ending
/// on a rest.
private let sample = """
  <?xml version="1.0" encoding="UTF-8"?>
  <score-partwise version="4.0">
    <work><work-title>Peça de teste</work-title></work>
    <identification><creator type="composer">Alguém</creator></identification>
    <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
    <part id="P1">
      <measure number="1">
        <attributes>
          <divisions>2</divisions>
          <key><fifths>1</fifths></key>
          <time><beats>3</beats><beat-type>4</beat-type></time>
        </attributes>
        <note><pitch><step>G</step><octave>4</octave></pitch><duration>2</duration></note>
        <note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration></note>
        <note><pitch><step>B</step><octave>4</octave></pitch><duration>2</duration></note>
      </measure>
      <measure number="2">
        <note><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch><duration>4</duration></note>
        <note><rest/><duration>2</duration></note>
      </measure>
    </part>
  </score-partwise>
  """

private func parsed() throws -> Score {
  try MusicXMLImporter.score(from: Data(sample.utf8))
}

// MARK: - Rule 64: the file is read

/// Rule 64 — title, composer, key and time signature all come across.
@Test func theHeaderIsRead() throws {
  let score = try parsed()

  #expect(score.title == "Peça de teste")
  #expect(score.composer == "Alguém")
  #expect(score.key.fifths == 1)
  #expect(score.timeSignature.beatsPerBar == 3)
  #expect(score.timeSignature.label == "3/4")
}

/// The bars arrive as bars, not as one long run of notes.
@Test func theBarsAreRead() throws {
  let score = try parsed()

  #expect(score.rightHand.measures.count == 2)
  #expect(score.rightHand.measures.first?.notes.count == 3)
}

/// Divisions are a ratio, not an absolute: two divisions per crotchet here.
@Test func divisionsBecomeWrittenFigures() throws {
  let score = try parsed()
  let first = score.rightHand.measures.first?.notes.first

  #expect(first?.duration.beats == 1, "duração 2 com divisions 2 é uma semínima")
  #expect(score.rightHand.measures.last?.notes.first?.duration.beats == 2)
}

/// Rule 65 — a rest is read as a rest, not dropped.
@Test func aRestIsRead() throws {
  let score = try parsed()
  let last = score.rightHand.measures.last?.notes.last

  #expect(last?.isRest == true)
  #expect(last?.duration.beats == 1)
}

/// The alteration is applied: F sharp is a semitone above F.
@Test func anAlterationIsApplied() throws {
  let score = try parsed()
  let sharp = score.rightHand.measures.last?.notes.first?.pitches.first

  #expect(sharp?.midiNoteNumber == 66, "Fá sustenido 4 é MIDI 66")
}

/// Octave 4 holds middle C, which pins the whole mapping.
@Test func middleCIsWhereMusicXMLSaysItIs() {
  #expect(MusicXMLImporter.Parser.pitch(step: "C", alter: 0, octave: 4)?.midiNoteNumber == 60)
  #expect(MusicXMLImporter.Parser.pitch(step: "A", alter: 0, octave: 4)?.midiNoteNumber == 69)
  #expect(MusicXMLImporter.Parser.pitch(step: "B", alter: -1, octave: 3)?.midiNoteNumber == 58)
}

/// An unknown step is refused rather than guessed.
@Test func anUnknownStepIsRefused() {
  #expect(MusicXMLImporter.Parser.pitch(step: "H", alter: 0, octave: 4) == nil)
}

/// Every imported bar fills, which is the same check the written pieces get.
@Test func animportedScoreFillsItsBars() throws {
  #expect(try parsed().isWellFormed)
}

// MARK: - Duration mapping

/// A dotted figure is recognised as dotted, not rounded to a plain one.
@Test func dottedFiguresAreRecognised() {
  // Três divisões com duas por semínima é uma semínima pontuada: 1,5 tempos.
  #expect(MusicXMLImporter.duration(divisions: 3, perQuarter: 2).isDotted)
  #expect(MusicXMLImporter.duration(divisions: 3, perQuarter: 2).beats == 1.5)

  // A mínima pontuada vale três, e são seis divisões quando duas valem uma.
  #expect(MusicXMLImporter.duration(divisions: 6, perQuarter: 2).beats == 3)
  #expect(MusicXMLImporter.duration(divisions: 6, perQuarter: 4).beats == 1.5)
}

/// Plain figures map straight across, whatever the file calls a crotchet.
@Test func plainFiguresMapAtAnyDivision() {
  for perQuarter in [1, 2, 4, 24, 480] {
    #expect(MusicXMLImporter.duration(divisions: perQuarter, perQuarter: perQuarter).beats == 1)
    #expect(MusicXMLImporter.duration(divisions: perQuarter * 4, perQuarter: perQuarter).beats == 4)
    #expect(
      MusicXMLImporter.duration(divisions: perQuarter / 2, perQuarter: perQuarter).beats == 0.5)
  }
}

/// The lower number of the time signature picks the beat figure.
@Test func theBeatTypeBecomesAFigure() {
  #expect(MusicXMLImporter.noteValue(forBeatType: 4) == .quarter)
  #expect(MusicXMLImporter.noteValue(forBeatType: 8) == .eighth)
  #expect(MusicXMLImporter.noteValue(forBeatType: 2) == .half)
}

// MARK: - Rule 65: refuse, with a reason

/// Rule 65 — bytes that are not XML are refused by name.
@Test func rubbishIsRefused() {
  #expect(throws: MusicXMLError.notXML) {
    try MusicXMLImporter.score(from: Data("isto não é xml".utf8))
  }
}

/// Rule 65 — XML that is not MusicXML is refused, and says so.
@Test func otherXMLIsRefused() {
  let other = Data("<?xml version=\"1.0\"?><lista><item/></lista>".utf8)

  #expect(throws: MusicXMLError.notPartwise) {
    try MusicXMLImporter.score(from: other)
  }
}

/// Rule 65 — a file with no bars is refused rather than opened empty.
@Test func anEmptyScoreIsRefused() {
  let empty = Data("<?xml version=\"1.0\"?><score-partwise></score-partwise>".utf8)

  #expect(throws: MusicXMLError.empty) {
    try MusicXMLImporter.score(from: empty)
  }
}

/// Every refusal explains itself in words the player can act on.
@Test func everyRefusalHasAMessage() {
  let all: [MusicXMLError] = [
    .notXML, .notPartwise, .empty, .noteWithoutDuration(measure: 3), .badDivisions,
  ]

  for error in all {
    #expect(!error.message.isEmpty, "\(error) não diz nada ao usuário")
    #expect(error.message.hasSuffix("."), "\(error) não é uma frase")
  }
}

/// The measure number reaches the message, so the player knows where to look.
@Test func aBadNoteSaysWhichBar() {
  #expect(MusicXMLError.noteWithoutDuration(measure: 7).message.contains("7"))
}
