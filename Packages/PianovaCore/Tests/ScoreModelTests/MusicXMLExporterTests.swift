import Foundation
import Testing

@testable import ScoreModel

/// Two bars in 3/4, one hand, with a rest and a dotted figure.
private let simple = Score(
  title: "Exportada", composer: "Alguém",
  timeSignature: .threeFour, key: .g,
  rightHand: Part(
    clef: .treble,
    measures: [
      Measure([
        ScoreNote(Pitch(67), .quarter), ScoreNote(Pitch(69), .eighth),
        ScoreNote(Pitch(71), .eighth), ScoreNote(Pitch(72), .quarter),
      ]),
      Measure([ScoreNote(Pitch(74), .half, dotted: true)]),
    ]))

/// A piece written out and read back is the same piece.
///
/// The round trip is the test that matters: it exercises both directions at
/// once, and a piece that survives it can be handed to an engraver.
@Test func aScoreSurvivesTheRoundTrip() throws {
  let xml = MusicXMLExporter.musicXML(for: simple)
  let back = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(back.title == "Exportada")
  #expect(back.composer == "Alguém")
  #expect(back.timeSignature.label == "3/4")
  #expect(back.key.fifths == 1)
  #expect(back.rightHand.measures.count == 2)
  #expect(back.isWellFormed)
}

/// Every written figure comes back as itself.
@Test func figuresSurviveTheRoundTrip() throws {
  let xml = MusicXMLExporter.musicXML(for: simple)
  let back = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(back.columns.map(\.duration.beats) == simple.columns.map(\.duration.beats))
  #expect(back.columns.last?.duration.isDotted == true, "o ponto deveria sobreviver")
}

/// Every pitch comes back as itself, accidentals included.
@Test func pitchesSurviveTheRoundTrip() throws {
  let chromatic = Score(
    title: "Cromática", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [Measure((60...63).map { ScoreNote(Pitch(UInt8($0)), .quarter) })]))

  let xml = MusicXMLExporter.musicXML(for: chromatic)
  let back = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(back.columns.flatMap(\.pitches).map(\.midiNoteNumber) == [60, 61, 62, 63])
}

/// A rest is written as a rest and read back as one.
@Test func restsSurviveTheRoundTrip() throws {
  let withRest = Score(
    title: "Com pausa", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(Pitch(60), .half), .rest(.quarter), ScoreNote(Pitch(62), .quarter),
        ])
      ]))

  let xml = MusicXMLExporter.musicXML(for: withRest)
  let back = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(back.columns.contains { $0.isRest })
  #expect(back.isWellFormed)
}

/// Both hands come back on their own staves.
@Test func twoHandsSurviveTheRoundTrip() throws {
  let twoHanded = Score(
    title: "Duas mãos", composer: "—",
    rightHand: Part(clef: .treble, measures: [Measure([ScoreNote(Pitch(72), .whole)])]),
    leftHand: Part(clef: .bass, measures: [Measure([ScoreNote(Pitch(48), .whole)])]))

  let xml = MusicXMLExporter.musicXML(for: twoHanded)
  let back = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(back.isTwoHanded)
  #expect(back.columns.first?.upper.first?.midiNoteNumber == 72)
  #expect(back.columns.first?.lower.first?.midiNoteNumber == 48)
}

/// A chord is written as one moment, not as notes in sequence.
@Test func chordsSurviveTheRoundTrip() throws {
  let chord = Score(
    title: "Acorde", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(pitches: [60, 64, 67].map { Pitch(UInt8($0)) }, duration: Duration(.whole))
        ])
      ]))

  let xml = MusicXMLExporter.musicXML(for: chord)
  let back = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(back.columns.count == 1, "um acorde é um instante, não três")
  #expect(back.columns.first?.pitches.count == 3)
}

/// Characters that would break the file are escaped.
@Test func awkwardTitlesAreEscaped() throws {
  let awkward = Score(
    title: "Bach & <Filhos>", composer: "—",
    rightHand: Part(clef: .treble, measures: [Measure([ScoreNote(Pitch(60), .whole)])]))

  let xml = MusicXMLExporter.musicXML(for: awkward)

  #expect(xml.contains("&amp;"))
  #expect(try MusicXMLImporter.score(from: Data(xml.utf8)).title == "Bach & <Filhos>")
}

// MARK: - Rule 122: digitação escrita

/// Rule 122 — uma nota com dedo declarado sai com <fingering> no MusicXML.
@Test func aFingeredNoteExportsItsFingering() {
  let score = Score(
    title: "Dedos", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(pitches: [Pitch(60)], duration: Duration(.quarter), fingers: [1]),
          ScoreNote(pitches: [Pitch(62)], duration: Duration(.quarter), fingers: [2]),
          ScoreNote(Pitch(64), .half),
        ])
      ]))

  let xml = MusicXMLExporter.musicXML(for: score)

  #expect(xml.contains("<fingering>1</fingering>"))
  #expect(xml.contains("<fingering>2</fingering>"))
}

/// Rule 122 — num acorde, cada nota leva o seu próprio dedo.
@Test func aChordExportsOneFingerPerNote() {
  let score = Score(
    title: "Acorde", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(
            pitches: [Pitch(60), Pitch(64), Pitch(67)], duration: Duration(.whole),
            fingers: [1, 3, 5])
        ])
      ]))

  let xml = MusicXMLExporter.musicXML(for: score)

  for finger in ["1", "3", "5"] {
    #expect(xml.contains("<fingering>\(finger)</fingering>"), "faltou o dedo \(finger)")
  }
}

/// Rule 122 — sem dedo declarado, nenhum <fingering> é inventado.
@Test func anUnfingeredNoteExportsNoFingering() {
  let score = Score(
    title: "Sem dedos", composer: "—",
    rightHand: Part(clef: .treble, measures: [Measure([ScoreNote(Pitch(60), .whole)])]))

  #expect(!MusicXMLExporter.musicXML(for: score).contains("fingering"))
}

// MARK: - Rules 128-130: o exportador escreve o que o modelo carrega

/// Rule 128 — pedal anotado sai como <pedal> no MusicXML.
@Test func pedalExportsAsDirections() {
  let score = Score(
    title: "Pedal", composer: "—",
    rightHand: Part(
      clef: .bass,
      measures: [
        Measure([
          ScoreNote(pitches: [Pitch(48)], duration: Duration(.half), pedal: .down),
          ScoreNote(pitches: [Pitch(55)], duration: Duration(.half), pedal: .up),
        ])
      ]))

  let xml = MusicXMLExporter.musicXML(for: score)

  #expect(xml.contains("<pedal type=\"start\""))
  #expect(xml.contains("<pedal type=\"stop\""))
}

/// Rule 129 — a oitava sai como <octave-shift> nos dois sentidos.
@Test func ottavaExportsAsOctaveShift() {
  let score = Score(
    title: "Oitava", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(pitches: [Pitch(84)], duration: Duration(.half), ottava: .startAbove),
          ScoreNote(pitches: [Pitch(86)], duration: Duration(.half), ottava: .stop),
        ])
      ]))

  let xml = MusicXMLExporter.musicXML(for: score)

  #expect(xml.contains("<octave-shift type=\"down\" size=\"8\""))
  #expect(xml.contains("<octave-shift type=\"stop\""))
}

/// Rule 130 — a ligadura de expressão sai como <slur> dentro de <notations>.
@Test func slursExportAsNotations() {
  let score = Score(
    title: "Ligada", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(pitches: [Pitch(60)], duration: Duration(.half), slurStart: true),
          ScoreNote(pitches: [Pitch(64)], duration: Duration(.half), slurStop: true),
        ])
      ]))

  let xml = MusicXMLExporter.musicXML(for: score)

  #expect(xml.contains("<slur type=\"start\""))
  #expect(xml.contains("<slur type=\"stop\""))
}
