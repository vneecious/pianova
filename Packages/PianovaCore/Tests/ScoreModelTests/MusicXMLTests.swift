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
  // Divisões pares só: com uma divisão por semínima o arquivo não consegue
  // escrever meia semínima, e `perQuarter / 2` daria zero.
  for perQuarter in [2, 4, 24, 480] {
    #expect(MusicXMLImporter.duration(divisions: perQuarter, perQuarter: perQuarter).beats == 1)
    #expect(MusicXMLImporter.duration(divisions: perQuarter * 4, perQuarter: perQuarter).beats == 4)
    #expect(
      MusicXMLImporter.duration(divisions: perQuarter / 2, perQuarter: perQuarter).beats == 0.5)
  }
  #expect(MusicXMLImporter.duration(divisions: 1, perQuarter: 1).beats == 1)
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

// MARK: - O que arquivos reais quebraram

/// Duas vozes na mesma pauta, escritas com `<backup>` entre elas.
///
/// É assim que todo editor escreve piano, e ignorar o `<backup>` empilha as
/// vozes uma depois da outra: o compasso sai com o dobro da duração.
private let twoVoices = """
  <?xml version="1.0"?>
  <score-partwise>
    <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
    <part id="P1">
      <measure number="1">
        <attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>8</duration><staff>1</staff></note>
        <note><pitch><step>D</step><octave>5</octave></pitch><duration>8</duration><staff>1</staff></note>
        <backup><duration>16</duration></backup>
        <note><pitch><step>C</step><octave>3</octave></pitch><duration>16</duration><staff>2</staff></note>
      </measure>
    </part>
  </score-partwise>
  """

/// O compasso fecha apesar das duas vozes sobrepostas.
@Test func backupKeepsTheBarFromDoubling() throws {
  let score = try MusicXMLImporter.score(from: Data(twoVoices.utf8))

  #expect(score.isWellFormed, "o compasso deveria fechar em 4 tempos")
  #expect(score.rightHand.measures.first?.beats == 4)
}

/// A mão que a `<backup>` reposiciona vira a outra pauta, e soa junto.
@Test func backupSeparatesTheHands() throws {
  let score = try MusicXMLImporter.score(from: Data(twoVoices.utf8))

  #expect(score.isTwoHanded)
  #expect(score.leftHand?.measures.first?.beats == 4)
  // As duas mãos começam no mesmo instante, então é um evento só.
  #expect(score.onsets.first?.pitches.count == 2)
}

/// A semicolcheia existe no modelo.
///
/// Sem ela, um prelúdio de Bach — que é só semicolcheia — tinha cada figura
/// arredondada para colcheia, e todo compasso saía com o dobro do tamanho.
@Test func sixteenthsAreRepresentable() {
  #expect(NoteValue.sixteenth.beats == 0.25)
  #expect(MusicXMLImporter.duration(divisions: 1, perQuarter: 4).value == .sixteenth)
  #expect(MusicXMLImporter.duration(divisions: 1, perQuarter: 4).beats == 0.25)
}

/// Cada figura continua valendo metade da anterior, agora até a semicolcheia.
@Test func theHalvingReachesTheSixteenth() {
  let ladder: [NoteValue] = [.whole, .half, .quarter, .eighth, .sixteenth]

  for (longer, shorter) in zip(ladder, ladder.dropFirst()) {
    #expect(longer.beats == shorter.beats * 2, "\(longer.name) não vale o dobro de \(shorter.name)")
  }
}

/// Rule 65 — uma partitura de orquestra é recusada, não lida pela metade.
///
/// Ler os dois primeiros instrumentos de um arquivo orquestral como duas mãos
/// produz algo plausível e sem sentido — flauta e oboé viram "piano".
@Test func anEnsembleScoreIsRefused() {
  var parts = ""
  for index in 1...22 {
    parts += "<score-part id=\"P\(index)\"><part-name>Instr \(index)</part-name></score-part>"
  }
  var body = ""
  for index in 1...22 {
    body += """
      <part id="P\(index)"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
      </measure></part>
      """
  }
  let data = Data(
    "<?xml version=\"1.0\"?><score-partwise><part-list>\(parts)</part-list>\(body)</score-partwise>"
      .utf8)

  #expect(throws: MusicXMLError.notForPiano(instruments: 22)) {
    try MusicXMLImporter.score(from: data)
  }
}

/// A recusa diz quantos instrumentos achou, para o usuário entender o motivo.
@Test func theRefusalCountsTheInstruments() {
  #expect(MusicXMLError.notForPiano(instruments: 22).message.contains("22"))
}

// MARK: - Rule 122: o importador preserva a digitação

/// Rule 122 — a digitação que vem no arquivo sobrevive à importação.
@Test func importedFingeringSurvives() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration>
        <type>half</type>
        <notations><technical><fingering>1</fingering></technical></notations></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>2</duration>
        <type>half</type>
        <notations><technical><fingering>3</fingering></technical></notations></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(score.rightHand.measures.first?.notes.first?.fingers == [1])
  #expect(score.rightHand.measures.first?.notes.last?.fingers == [3])
}

/// Rule 122 — nota sem digitação importa sem dedo nenhum.
@Test func importWithoutFingeringStaysBare() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration>
        <type>whole</type></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(score.rightHand.measures.first?.notes.first?.fingers.isEmpty == true)
}

// MARK: - Rule 127: ornamentos não são julgados

/// Rule 127 — uma grace note não derruba a peça nem entra no julgamento.
///
/// Ela não tem duração própria, e era por isso que o importador recusava o
/// arquivo inteiro ("compasso 5 tem uma nota sem duração") — a valsa de
/// Chopin caiu exatamente aí.
@Test func aGraceNoteIsSkippedNotFatal() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <note><grace/><pitch><step>B</step><octave>4</octave></pitch>
        <type>eighth</type></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration>
        <type>half</type></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>2</duration>
        <type>half</type></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))
  let first = try #require(score.rightHand.measures.first?.notes.first)

  #expect(first.pitches == [Pitch(69)], "a grace note não pode entrar no acorde")
  #expect(score.rightHand.measures.first?.notes.count == 2)
}

/// Rule 127 — o ornamento é preservado ancorado à nota que decora, com a
/// digitação que carrega; a nota real e as pendências não mudam.
@Test func gracesSurviveImportAnchoredToTheirNote() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <direction><direction-type><dynamics><mf/></dynamics></direction-type></direction>
      <note><grace/><pitch><step>B</step><octave>5</octave></pitch><type>16th</type>
        <notations><technical><fingering>2</fingering></technical></notations></note>
      <note><grace/><pitch><step>C</step><octave>6</octave></pitch><type>16th</type>
        <notations><technical><fingering>4</fingering></technical></notations></note>
      <note><pitch><step>B</step><octave>5</octave></pitch><duration>8</duration>
        <type>half</type></note>
      <note><pitch><step>A</step><octave>5</octave></pitch><duration>8</duration>
        <type>half</type></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))
  let notes = try #require(score.rightHand.measures.first?.notes)

  #expect(notes.count == 2, "o ornamento não cria coluna própria")
  #expect(notes[0].pitches == [Pitch(83)])
  #expect(
    notes[0].graces == [
      GraceNote(pitch: Pitch(83), finger: 2), GraceNote(pitch: Pitch(84), finger: 4),
    ])
  #expect(notes[0].dynamic == "mf", "a dinâmica atravessa o ornamento até a nota real")
  #expect(notes[1].graces.isEmpty)
}

/// Rule 128 — o estilo de linha do pedal sobrevive à importação.
@Test func pedalLineStyleSurvivesImport() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <direction><direction-type><pedal type="start" line="yes"/></direction-type></direction>
      <note><pitch><step>C</step><octave>3</octave></pitch><duration>2</duration>
        <type>half</type></note>
      <direction><direction-type><pedal type="stop" line="yes"/></direction-type></direction>
      <note><pitch><step>G</step><octave>3</octave></pitch><duration>2</duration>
        <type>half</type></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))
  let notes = try #require(score.rightHand.measures.first?.notes)

  #expect(notes[0].pedal == .down)
  #expect(notes[0].pedalLine, "o arquivo escreveu linha; o modelo tem que lembrar")
  #expect(notes[1].pedal == .up)
  #expect(notes[1].pedalLine)
}

// MARK: - Rules 128-130: pedal, oitava e ligaduras atravessam o cano

/// Rule 128 — as marcas de pedal do arquivo sobrevivem à importação.
@Test func pedalMarksSurviveImport() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <direction><direction-type><pedal type="start"/></direction-type></direction>
      <note><pitch><step>C</step><octave>3</octave></pitch><duration>2</duration>
        <type>half</type></note>
      <direction><direction-type><pedal type="stop"/></direction-type></direction>
      <note><pitch><step>G</step><octave>3</octave></pitch><duration>2</duration>
        <type>half</type></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))
  let notes = try #require(score.rightHand.measures.first?.notes)

  #expect(notes[0].pedal == .down)
  #expect(notes[1].pedal == .up)
}

/// Rule 129 — a oitava vira notação; as alturas seguem sendo as que soam.
@Test func octaveShiftSurvivesImportWithoutChangingPitches() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <direction><direction-type><octave-shift type="down" size="8"/></direction-type></direction>
      <note><pitch><step>C</step><octave>6</octave></pitch><duration>2</duration>
        <type>half</type></note>
      <direction><direction-type><octave-shift type="stop" size="8"/></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration>
        <type>half</type></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))
  let notes = try #require(score.rightHand.measures.first?.notes)

  #expect(notes[0].pitches == [Pitch(84)], "a altura que soa não muda")
  #expect(notes[0].ottava == .startAbove)
  #expect(notes[1].ottava == .stop)
}

/// Rule 130 — as ligaduras de expressão sobrevivem, sem virar ligadura de valor.
@Test func slursSurviveImportWithoutBecomingTies() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration>
        <type>half</type><notations><slur type="start" number="1"/></notations></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>2</duration>
        <type>half</type><notations><slur type="stop" number="1"/></notations></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))
  let notes = try #require(score.rightHand.measures.first?.notes)

  #expect(notes[0].slurStart)
  #expect(notes[1].slurStop)
  #expect(!notes[0].isTiedToNext, "ligadura de expressão não é ligadura de valor")
}

/// Rule 134 — a quiáltera entra no modelo como escrita: figura, razão e
/// colchete, e o compasso fecha a conta.
@Test func tupletsSurviveImportAsWritten() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>60</divisions>
      <time><beats>3</beats><beat-type>4</beat-type></time></attributes>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>20</duration>
        <type>eighth</type>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
        <notations><tuplet type="start"/></notations></note>
      <note><pitch><step>G</step><alter>1</alter><octave>4</octave></pitch><duration>20</duration>
        <type>eighth</type>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
      <note><pitch><step>B</step><octave>4</octave></pitch><duration>20</duration>
        <type>eighth</type>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
        <notations><tuplet type="stop"/></notations></note>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>120</duration>
        <type>half</type></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))
  let notes = try #require(score.rightHand.measures.first?.notes)

  #expect(notes.count == 4)
  #expect(notes[0].duration.value == .eighth)
  #expect(notes[0].duration.tuplet == TupletRatio(actual: 3, normal: 2))
  #expect(abs(notes[0].duration.beats - 1.0 / 3.0) < 0.001)
  #expect(notes[0].tupletStart)
  #expect(notes[2].tupletStop)
  #expect(score.isWellFormed, "três terços e uma mínima fecham o 3/4")
}

/// Rule 132 — o trilo escrito na nota sobrevive à importação.
@Test func aTrillSurvivesImport() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>4</duration>
        <type>whole</type><notations><ornaments><trill-mark/></ornaments></notations></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))
  let note = try #require(score.rightHand.measures.first?.notes.first)

  #expect(note.articulations.contains(.trill))
}

/// Sonda — direção com `<staff>` num arquivo de pauta dupla chega à mão certa.
@Test func aDirectionWithStaffReachesItsHand() throws {
  let xml = """
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions><staves>2</staves></attributes>
      <direction placement="above">
        <direction-type><dynamics><mp/></dynamics></direction-type>
        <staff>2</staff>
      </direction>
      <direction>
        <direction-type><octave-shift type="stop" size="8"/></direction-type>
        <staff>1</staff>
      </direction>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>whole</type><voice>1</voice><staff>1</staff></note>
      <backup><duration>4</duration></backup>
      <note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration>
        <type>whole</type><voice>2</voice><staff>2</staff></note>
    </measure></part></score-partwise>
    """

  let score = try MusicXMLImporter.score(from: Data(xml.utf8))

  #expect(score.rightHand.measures.first?.notes.first?.ottava == .stop, "oitava na pauta 1")
  #expect(score.leftHand?.measures.first?.notes.first?.dynamic == "mp", "mp na pauta 2")
}
