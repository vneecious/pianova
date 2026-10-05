import Foundation
import ScoreModel
import Testing

@testable import Sound

/// Bancada: o ouvido neural na gravação real do dono (regra 153).
@Test func benchNeuralEarOnTheRealRecording() throws {
  let path =
    "/private/tmp/claude-501/-Users-I550329-Projects-piano/e0718545-c049-43d1-b148-ce47a2d273f4/scratchpad/teste-vivo-48k.wav"
  guard let raw = try? Data(contentsOf: URL(fileURLWithPath: path)),
    let found = raw.range(of: Data("data".utf8))
  else { return }
  let payload = raw.subdata(in: (found.upperBound + 4)..<raw.count)
  var pcm = [Int16](repeating: 0, count: payload.count / 2)
  _ = pcm.withUnsafeMutableBytes { payload.copyBytes(to: $0) }
  let samples = pcm.map { Float($0) / 32768 }

  let ear = try NeuralEar(sampleRate: 48_000)
  let clock = ContinuousClock()
  let started = clock.now
  let heard = ear.listen(to: samples)
  let elapsed = clock.now - started

  let names = ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"]
  func nm(_ p: Pitch) -> String {
    let m = Int(p.midiNoteNumber)
    return "\(names[m % 12])\(m / 12 - 1)"
  }
  var groups: [(Double, [Pitch])] = []
  for h in heard {
    if var last = groups.last, h.time - last.0 < 0.12 {
      last.1.append(h.pitch)
      groups[groups.count - 1] = last
    } else {
      groups.append((h.time, [h.pitch]))
    }
  }
  print("NEURAL notas=\(heard.count) grupos=\(groups.count) tempo=\(elapsed) para 45s de áudio")
  for (t, ps) in groups where t >= 5 && t <= 15 {
    print(
      String(
        format: "NEURAL %6.2fs  %@", t,
        ps.sorted { $0.midiNoteNumber < $1.midiNoteNumber }.map(nm).joined(separator: " ")))
  }
}
