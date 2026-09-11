import Engraving
import EngravingVerovio
import Foundation
import ScoreModel
import Testing

// MARK: - Rule 128: a linha de pedal é desenhada

/// Rule 128 — pedal escrito em linha chega à página como formas desenháveis.
///
/// O Verovio desenha a linha com cantoneiras como `<rect>`s; um parser que só
/// lê `<path>` e `<use>` derruba a lane inteira em silêncio.
@Test func pedalLineIsDrawnOnThePage() throws {
  let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
    <part-list><score-part id="P1"><part-name></part-name></score-part></part-list>
    <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions>
    <key><fifths>0</fifths></key>
    <time><beats>3</beats><beat-type>4</beat-type></time>
    <clef><sign>F</sign><line>4</line></clef></attributes>
    <direction placement="below"><direction-type>
    <pedal type="start" line="yes"/></direction-type></direction>
    <note><pitch><step>A</step><octave>2</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    <note><pitch><step>E</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    <note><pitch><step>A</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    <direction placement="below"><direction-type>
    <pedal type="stop" line="yes"/></direction-type></direction>
    </measure></part></score-partwise>
    """

  let engraver = Engraver()
  #expect(engraver.load(musicXML: xml))

  let page = try #require(engraver.page(1))
  let pedalShapes = page.shapes.filter { $0.kind?.contains("pedal") == true }

  #expect(!pedalShapes.isEmpty, "a linha do pedal tem que virar forma desenhável")
  // A linha corre na horizontal: alguma das formas é bem mais larga que alta.
  let wide = pedalShapes.contains { shape in
    let box = shape.path.boundingBox
    return box.width > box.height * 4
  }
  #expect(wide, "entre as formas do pedal tem que existir a barra horizontal")
}

// MARK: - Rule 127: ornamentos desenhados, fora do julgamento

/// Rule 127 — a grace aparece na página, mas não no mapa de eventos; a nota
/// decorada volta para o tempo escrito, junto do baixo que soa com ela.
@Test func gracesAreDrawnButNotJudged() throws {
  let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
    <part-list><score-part id="P1"><part-name></part-name></score-part></part-list>
    <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions>
    <key><fifths>0</fifths></key>
    <time><beats>3</beats><beat-type>4</beat-type></time>
    <staves>2</staves>
    <clef number="1"><sign>G</sign><line>2</line></clef>
    <clef number="2"><sign>F</sign><line>4</line></clef></attributes>
    <note><grace/><pitch><step>B</step><octave>5</octave></pitch><voice>1</voice><type>16th</type><staff>1</staff>
    <notations><technical><fingering>2</fingering></technical></notations></note>
    <note><grace/><pitch><step>C</step><octave>6</octave></pitch><voice>1</voice><type>16th</type><staff>1</staff>
    <notations><technical><fingering>4</fingering></technical></notations></note>
    <note><pitch><step>B</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
    <note><pitch><step>A</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
    <note><pitch><step>E</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
    <backup><duration>12</duration></backup>
    <note><pitch><step>A</step><octave>2</octave></pitch><duration>4</duration><voice>2</voice><type>quarter</type><staff>2</staff></note>
    <note><pitch><step>E</step><octave>3</octave></pitch><duration>4</duration><voice>2</voice><type>quarter</type><staff>2</staff></note>
    <note><pitch><step>A</step><octave>3</octave></pitch><duration>4</duration><voice>2</voice><type>quarter</type><staff>2</staff></note>
    </measure></part></score-partwise>
    """

  let engraver = Engraver()
  #expect(engraver.load(musicXML: xml))

  let events = engraver.events()

  // Três momentos escritos, três eventos — o ornamento não cria momento.
  #expect(events.count == 3)

  let first = try #require(events.first)
  #expect(first.time == 0, "a nota decorada volta para o tempo escrito")
  #expect(
    Set(first.pitches) == Set([Pitch(83), Pitch(45)]),
    "a nota decorada e o baixo dela são um momento só")

  // A appoggiatura (C6 = 84) não é cobrada em momento nenhum.
  #expect(events.allSatisfy { !$0.pitches.contains(Pitch(84)) })

  // Mas ela ESTÁ na página, miúda, com a digitação junto.
  let page = try #require(engraver.page(1))
  #expect((page.texts.map(\.text)).contains("2"), "a digitação da grace aparece")
  #expect((page.texts.map(\.text)).contains("4"))
}
