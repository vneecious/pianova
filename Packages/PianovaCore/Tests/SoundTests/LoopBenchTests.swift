import ExerciseEngine
import Foundation
import ScoreModel
import Testing

@testable import Sound

private func bench(_ path: String) -> String {
  guard let raw = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return "no file" }
  guard let found = raw.range(of: Data("data".utf8)) else { return "no data chunk" }
  let payload = raw.subdata(in: (found.upperBound + 4)..<raw.count)
  var samples = [Float](repeating: 0, count: payload.count / 4)
  _ = samples.withUnsafeMutableBytes { payload.copyBytes(to: $0) }

  let melody: [[UInt8]] = [
    [64, 48], [64], [64, 55], [65], [64], [62],
    [60, 48], [60], [60, 55], [62], [60], [59],
    [57, 53], [59], [60, 55], [62], [64], [62], [65], [64],
    [62, 55], [60], [62, 55], [64], [62], [59],
  ]
  let judge = NoteDetector(sampleRate: 48_000)
  var session = ExerciseSession(
    exercise: Exercise(items: melody.map { ExerciseItem(pitches: Set($0.map(Pitch.init))) }))
  var advances: [String] = []
  var wrongs = 0
  var cursor = 0
  func refreshExpectation() {
    guard let item = session.currentItem else { return }
    let next =
      session.exercise.items.indices.contains(session.cursorIndex + 1)
      ? session.exercise.items[session.cursorIndex + 1].pitches : []
    judge.expect(item.pitches, next: next, among: Pitch(45)...Pitch(84))
  }
  refreshExpectation()
  while cursor + 1024 <= samples.count, !session.isFinished {
    for hit in judge.process(Array(samples[cursor..<(cursor + 1024)])) {
      let was = session.cursorIndex
      let outcome = session.press(hit.pitch, at: Double(cursor) / 48_000)
      if outcome == .wrong { wrongs += 1 }
      if session.cursorIndex != was {
        advances.append(String(format: "%.1fs:c%d", Double(cursor) / 48_000, was))
      }
      refreshExpectation()
    }
    cursor += 1024
  }
  return
    "advanced=\(session.cursorIndex)/\(melody.count) wrongs=\(wrongs) erros=\(session.mistakeCount) [\(advances.joined(separator: " "))]"
}

@Test func benchClosedLoop() {
  let base =
    "/private/tmp/claude-501/-Users-I550329-Projects-piano/e0718545-c049-43d1-b148-ce47a2d273f4/scratchpad"
  print("LOOP-DIRECT \(bench(base + "/cancan-synth.wav"))")
  print("LOOP-AIR \(bench(base + "/cancan-air.wav"))")
}
