// Pianova Import — passa um MusicXML pelo importador e relata o que saiu.
//
// Arquivo de teste concorda com quem o escreveu. Isto lê arquivos reais,
// gerados por editores de verdade, que é onde os casos não previstos aparecem.
//
//   swift run --package-path Packages/PianovaCore PianovaImport <arquivo>...

import Foundation
import ScoreModel

for path in CommandLine.arguments.dropFirst() {
  let url = URL(fileURLWithPath: path)
  print("\n=== \(url.lastPathComponent)")

  do {
    let score = try MusicXMLImporter.score(at: url)

    print("  título:    \(score.title)")
    print("  compositor:\(score.composer)")
    print("  compasso:  \(score.timeSignature.label)   armadura: \(score.key.fifths)")
    print("  mãos:      \(score.isTwoHanded ? "duas" : "uma")   anacruse: \(score.hasPickup)")
    print("  compassos: \(score.rightHand.measures.count)")
    print("  colunas:   \(score.columns.count)   a tocar: \(score.onsets.count)")

    let bad = score.incompleteMeasures
    if bad.isEmpty {
      print("  compassos: todos fecham ✓")
    } else {
      print(
        "  INCOMPLETOS: \(bad.count) — primeiros: \(bad.prefix(5).map { "\($0.part) #\($0.index + 1)" })"
      )
    }

    let pitches = score.columns.flatMap(\.pitches).map(\.midiNoteNumber)
    if let low = pitches.min(), let high = pitches.max() {
      print("  extensão:  \(Pitch(low).scientificName) a \(Pitch(high).scientificName)")
    }
  } catch let error as MusicXMLError {
    print("  RECUSADO: \(error.message)")
  } catch {
    print("  ERRO: \(error)")
  }
}
