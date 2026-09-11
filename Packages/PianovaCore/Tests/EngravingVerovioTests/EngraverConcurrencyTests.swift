import EngravingVerovio
import Foundation
import ScoreModel
import Testing

/// Um gravador, muitos chamadores, nenhuma queda.
///
/// O slider de tamanho regrava por degrau enquanto a gravação anterior ainda
/// corre. Sem serializar, o toolkit corrompe a memória e derruba o app — foi
/// o crash do tamanho mínimo.
@Test func concurrentEngravingDoesNotCrash() async throws {
  let score = Score(
    title: "Corrida", composer: "—",
    timeSignature: .threeFour,
    rightHand: Part(
      clef: .treble,
      measures: (0..<24)
        .map { index in
          Measure(
            (0..<3)
              .map { beat in
                ScoreNote(Pitch(UInt8(60 + (index + beat) % 24)), .quarter)
              })
        }))
  let xml = MusicXMLExporter.musicXML(for: score)

  let engraver = Engraver()
  await withTaskGroup(of: Void.self) { group in
    for width in [2700, 2400, 2100, 1850, 1600, 1400, 2700, 1400] {
      group.addTask {
        _ = engraver.load(musicXML: xml, width: width, height: 2970)
        _ = engraver.page(1)
        _ = engraver.events()
      }
    }
  }

  #expect(engraver.pageCount >= 1)
}
