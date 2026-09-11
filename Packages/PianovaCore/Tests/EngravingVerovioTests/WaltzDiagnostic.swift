import Engraving
import EngravingVerovio
import Foundation
import ScoreModel
import Testing

/// Diagnóstico temporário com o arquivo real da valsa: o que sobrevive?
@Test func waltzRoundTripInventory() throws {
  let path =
    "/private/tmp/claude-501/-Users-I550329-Projects-piano/"
    + "dae134ef-c880-4f80-bd16-7bf97ae56143/scratchpad/waltz/score.xml"
  guard FileManager.default.fileExists(atPath: path) else { return }

  let score = try MusicXMLImporter.score(at: URL(fileURLWithPath: path))
  let all = (score.rightHand.measures + (score.leftHand?.measures ?? [])).flatMap(\.notes)

  print("MODELO: pedal=\(all.compactMap(\.pedal).count) ottava=\(all.compactMap(\.ottava).count)")
  print(
    "MODELO: slurStart=\(all.filter(\.slurStart).count) slurStop=\(all.filter(\.slurStop).count)")
  print("MODELO: dyn=\(all.compactMap(\.dynamic).count) words=\(all.compactMap(\.words).count)")
  print(
    "MODELO: artic=\(all.map(\.articulations.count).reduce(0,+)) fingers=\(all.filter { !$0.fingers.isEmpty }.count)"
  )

  let xml = MusicXMLExporter.musicXML(for: score)
  for tag in ["pedal", "octave-shift", "slur", "dynamics", "words", "staccato"] {
    print("XML: \(tag)=\(xml.components(separatedBy: "<\(tag)").count - 1)")
  }

  let engraver = Engraver()
  engraver.load(musicXML: xml)
  let page = engraver.page(1)
  let kinds = (page?.shapes ?? []).compactMap(\.kind)
  for kind in ["slur", "pedal", "octave", "dynam", "artic"] {
    print("PÁGINA: \(kind)=\(kinds.filter { $0.contains(kind) }.count)")
  }
  print("PÁGINA: textos=\((page?.texts ?? []).map(\.text))")
}
