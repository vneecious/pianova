import ExerciseEngine
import Foundation
import ScoreModel
import Testing

@testable import Sound

// MARK: - Rules 151 and 153: a escuta ao vivo leva o cursor até o fim

/// The owner's own Can-Can, streamed chunk by chunk through the ear and the
/// very judge the app uses.
///
/// Nothing here is a stand-in: his piano, his microphone, his playing, the
/// real `ExerciseSession`. If this walks to the last column, the study walks
/// on the iPad.
@Test func theOwnersPlayingWalksTheCursorToTheEnd() throws {
  let url = try #require(
    Bundle.module.url(forResource: "ref-cancan", withExtension: "wav", subdirectory: "Recordings"))
  let raw = try Data(contentsOf: url)
  let found = try #require(raw.range(of: Data("data".utf8)))
  let payload = raw.subdata(in: (found.upperBound + 4)..<raw.count)
  var pcm = [Int16](repeating: 0, count: payload.count / 2)
  _ = pcm.withUnsafeMutableBytes { payload.copyBytes(to: $0) }
  let samples = pcm.map { Float($0) / 32768 }

  // O Can-Can como o app o julga: colunas com as duas mãos.
  let columns: [[UInt8]] = [
    [64, 48], [64], [64, 55], [65], [64], [62],
    [60, 48], [60], [60, 55], [62], [60], [59],
    [57, 53], [59], [60, 55], [62], [64], [62], [65], [64],
    [62, 55], [60], [62, 55], [64], [62], [59],
  ]

  let ear = try NeuralEar(sampleRate: 22_050)
  ear.onsetThreshold = 0.8
  var session = ExerciseSession(
    exercise: Exercise(items: columns.map { ExerciseItem(pitches: Set($0.map(Pitch.init))) }))

  /// The page tells the ear what it is waiting for, now and next (rule 151).
  func guide() {
    var wanted = session.currentItem?.pitches ?? []
    if session.exercise.items.indices.contains(session.cursorIndex + 1) {
      wanted.formUnion(session.exercise.items[session.cursorIndex + 1].pitches)
    }
    ear.lenientPitches = wanted
  }
  guide()

  var cursor = 0
  while cursor + 2048 <= samples.count, !session.isFinished {
    for hit in ear.hear(Array(samples[cursor..<(cursor + 2048)])) {
      _ = session.press(hit.pitch, at: hit.time)
      guide()
    }
    cursor += 2048
  }

  #expect(session.isFinished, "parou na coluna \(session.cursorIndex) de \(columns.count)")
  #expect(session.mistakeCount < 40, "sem chover vermelho: \(session.mistakeCount) acusações")
}
