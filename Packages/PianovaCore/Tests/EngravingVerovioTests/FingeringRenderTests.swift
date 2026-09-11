import Engraving
import EngravingVerovio
import ScoreModel
import Testing

// MARK: - Rule 122: a digitação escrita chega à página

/// Rule 122 — uma nota com dedo gravada pelo Verovio traz o número na página.
///
/// O dedo atravessava modelo e MusicXML e sumia aqui: o Verovio desenha
/// digitação como texto no SVG, e o parser só lia caminhos — todo texto era
/// descartado em silêncio.
@Test func aFingeredNoteReachesThePageAsText() {
  let score = Score(
    title: "Dedo", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(pitches: [Pitch(60)], duration: Duration(.whole), fingers: [3])
        ])
      ]))

  let engraver = Engraver()
  engraver.load(musicXML: MusicXMLExporter.musicXML(for: score))
  let page = engraver.page(1)

  #expect(page?.texts.contains { $0.text == "3" } == true, "o 3 deveria estar na página")
}

/// O texto sabe onde fica e que tamanho tem, senão não há como desenhá-lo.
@Test func aPageTextKnowsItsPlaceAndSize() throws {
  let score = Score(
    title: "Dedo", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(pitches: [Pitch(64)], duration: Duration(.whole), fingers: [2])
        ])
      ]))

  let engraver = Engraver()
  engraver.load(musicXML: MusicXMLExporter.musicXML(for: score))
  let page = try #require(engraver.page(1))
  let finger = try #require(page.texts.first { $0.text == "2" })

  #expect(finger.position.x > 0)
  #expect(finger.position.y > 0)
  #expect(finger.fontSize > 0)
}

/// Rule 124 — nenhum "Piano" impresso no alto do sistema.
@Test func noPartLabelIsPrinted() {
  let score = Score(
    title: "Sem rótulo", composer: "—",
    rightHand: Part(clef: .treble, measures: [Measure([ScoreNote(Pitch(60), .whole)])]))

  let engraver = Engraver()
  engraver.load(musicXML: MusicXMLExporter.musicXML(for: score))
  let page = engraver.page(1)

  #expect(page?.texts.contains { $0.text.localizedCaseInsensitiveContains("piano") } == false)
}
