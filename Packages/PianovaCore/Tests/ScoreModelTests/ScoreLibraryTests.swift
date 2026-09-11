import Foundation
import Testing

@testable import ScoreModel

/// A minimal but valid piano file.
private let sample = """
  <?xml version="1.0"?>
  <score-partwise>
    <work><work-title>Guardada</work-title></work>
    <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
    <part id="P1"><measure number="1">
      <attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure></part>
  </score-partwise>
  """

/// A library in its own scratch folder, so tests never touch real files.
private func scratchLibrary(_ name: String) -> ScoreLibrary {
  let folder = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("PianovaTests-\(name)", isDirectory: true)
  try? FileManager.default.removeItem(at: folder)
  return ScoreLibrary(folder: folder)
}

private func write(_ text: String, named name: String) -> URL {
  let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
  try? text.write(to: url, atomically: true, encoding: .utf8)
  return url
}

/// Rule 90 — what was imported is still there next time.
@Test func anImportedScoreSurvives() throws {
  let library = scratchLibrary("survives")
  let file = write(sample, named: "guardada.musicxml")

  _ = try library.add(file)

  // A second library over the same folder is what a relaunch looks like.
  let reopened = ScoreLibrary(folder: library.folder)
  #expect(reopened.scores().map(\.title) == ["Guardada"])
}

/// Rule 91 — the original file is what is kept.
@Test func theOriginalFileIsWhatIsStored() throws {
  let library = scratchLibrary("original")
  _ = try library.add(write(sample, named: "guardada.musicxml"))

  #expect(library.files().count == 1)
  #expect(library.files().first?.pathExtension == "musicxml")

  let kept = try String(contentsOf: library.files()[0], encoding: .utf8)
  #expect(kept == sample, "o arquivo deveria ser guardado como veio")
}

/// Rule 92 — a score can be taken out again.
@Test func aScoreCanBeRemoved() throws {
  let library = scratchLibrary("remove")
  _ = try library.add(write(sample, named: "guardada.musicxml"))

  library.remove(titled: "Guardada")

  #expect(library.scores().isEmpty)
  #expect(library.files().isEmpty)
}

/// A file that cannot be read is refused before it is kept.
///
/// Refusing an unreadable file is no use if the library fills up with it anyway.
@Test func anUnreadableFileIsNotKept() {
  let library = scratchLibrary("refuses")
  let bad = write("isto não é xml", named: "ruim.musicxml")

  #expect(throws: MusicXMLError.notXML) { try library.add(bad) }
  #expect(library.files().isEmpty, "nada deveria ter sido copiado")
}

/// Importing the same file twice leaves one copy, not two.
@Test func importingTwiceKeepsOneCopy() throws {
  let library = scratchLibrary("twice")
  let file = write(sample, named: "guardada.musicxml")

  _ = try library.add(file)
  _ = try library.add(file)

  #expect(library.files().count == 1)
}

/// An empty library is empty, not a crash.
@Test func anEmptyLibraryReadsAsEmpty() {
  #expect(scratchLibrary("empty").scores().isEmpty)
}
