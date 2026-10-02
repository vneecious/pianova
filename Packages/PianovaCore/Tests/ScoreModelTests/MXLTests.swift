import Foundation
import Testing

@testable import ScoreModel

// MARK: - Rule 146: o .mxl é bem-vindo

/// Rule 146 — o MusicXML comprimido abre como o plano: o container aponta
/// o arquivo raiz.
@Test func aCompressedMusicXMLOpensLikeThePlainOne() throws {
  let url = try #require(
    Bundle.module.url(forResource: "tiny", withExtension: "mxl", subdirectory: "Fixtures"))

  let score = try MusicXMLImporter.score(at: url)

  #expect(score.melody == [Pitch(60)])
}

/// Rule 146 — sem container.xml, vale o primeiro .xml do pacote.
@Test func anMXLWithoutContainerStillOpens() throws {
  let url = try #require(
    Bundle.module.url(forResource: "naked", withExtension: "mxl", subdirectory: "Fixtures"))

  let score = try MusicXMLImporter.score(at: url)

  #expect(score.melody == [Pitch(60)])
}

/// Rule 146 — a biblioteca guarda e lista .mxl como qualquer partitura.
@Test func theLibraryKeepsCompressedScores() throws {
  let temp = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  defer { try? FileManager.default.removeItem(at: temp) }
  let library = ScoreLibrary(folder: temp, legacy: temp.appendingPathComponent("nowhere"))
  let url = try #require(
    Bundle.module.url(forResource: "tiny", withExtension: "mxl", subdirectory: "Fixtures"))

  try library.add(url)

  #expect(library.files().count == 1)
  #expect(library.scores().count == 1)
}
