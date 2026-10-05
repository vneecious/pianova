import Foundation
import ScoreModel
import Testing

@testable import Sound

/// Bancada: a gravação real do dono, pelo juiz — mede avanço, não passa/falha.
@Test func benchCancanRecording() throws {
  let url = URL(
    fileURLWithPath:
      "/private/tmp/claude-501/-Users-I550329-Projects-piano/e0718545-c049-43d1-b148-ce47a2d273f4/scratchpad/cancan.wav"
  )
  guard let raw = try? Data(contentsOf: url) else { return }
  let at = raw.range(of: Data("data".utf8))!.upperBound + 4
  let payload = raw.subdata(in: at..<raw.count)
  var samples = [Float](repeating: 0, count: payload.count / 4)
  _ = samples.withUnsafeMutableBytes { payload.copyBytes(to: $0) }

  let melody: [[UInt8]] = [
    [64, 48], [64], [64, 55], [65], [64], [62],
    [60, 48], [60], [60, 55], [62], [60], [59],
    [57, 53], [59], [60, 55], [62], [64], [62], [65], [64],
    [62, 55], [60], [62, 55], [64], [62], [59],
  ]
  let judge = NoteDetector(sampleRate: 48_000)
  var columnIndex = 0
  var remaining = Set(melody[0].map(Pitch.init))
  judge.expect(remaining, among: Pitch(45)...Pitch(84))
  var advances: [String] = []
  var cursor = 0
  let hop = 1024
  while cursor + hop <= samples.count, columnIndex < melody.count {
    for hit in judge.process(Array(samples[cursor..<(cursor + hop)])) {
      if remaining.contains(hit.pitch) {
        remaining.remove(hit.pitch)
        if remaining.isEmpty {
          advances.append(String(format: "%.1fs:c%d", Double(cursor) / 48_000, columnIndex))
          columnIndex += 1
          if columnIndex < melody.count {
            remaining = Set(melody[columnIndex].map(Pitch.init))
          }
        }
        judge.expect(remaining, among: Pitch(45)...Pitch(84))
      }
    }
    cursor += hop
  }
  print("BENCH advanced=\(columnIndex)/\(melody.count) \(advances.joined(separator: " "))")
}
