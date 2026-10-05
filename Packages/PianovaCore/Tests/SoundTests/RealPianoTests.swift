import Foundation
import ScoreModel
import Testing

@testable import Sound

// MARK: - Rule 153: a bancada é o dono tocando de verdade

/// The owner playing a piece on his own P-145, through a real microphone.
///
/// Synthetic tones prove the plumbing; only this proves the ear.
private func heard(in recording: String) throws -> [Pitch] {
  let url = try #require(
    Bundle.module.url(forResource: recording, withExtension: "wav", subdirectory: "Recordings"))
  let raw = try Data(contentsOf: url)
  let found = try #require(raw.range(of: Data("data".utf8)))
  let payload = raw.subdata(in: (found.upperBound + 4)..<raw.count)
  var pcm = [Int16](repeating: 0, count: payload.count / 2)
  _ = pcm.withUnsafeMutableBytes { payload.copyBytes(to: $0) }

  let ear = try NeuralEar(sampleRate: 22_050)
  return ear.listen(to: pcm.map { Float($0) / 32768 }).map(\.pitch)
}

/// Whether a written line appears inside what was heard, in order.
///
/// A subsequence, not a stretch: the ear also hears the other hand and the
/// odd overtone, and a melody is still a melody with notes in between.
private func contains(
  _ line: [UInt8], within pitches: [Pitch], range: ClosedRange<UInt8>
)
  -> Bool
{
  // Repeated notes often arrive merged, so both sides lose their stutters.
  func squashed(_ values: [UInt8]) -> [UInt8] {
    values.reduce(into: [UInt8]()) { out, value in
      if out.last != value { out.append(value) }
    }
  }
  let sung = squashed(pitches.map(\.midiNoteNumber).filter { range.contains($0) })
  let wanted = squashed(line)

  var index = 0
  for note in sung where note == wanted[index] {
    index += 1
    if index == wanted.count { return true }
  }
  return false
}

/// Rule 153 — a melodia do Can-Can está lá, na ordem escrita.
@Test func theEarFindsTheCanCanMelody() throws {
  let pitches = try heard(in: "ref-cancan")
  // Mi Mi Mi Fá Mi Ré | Dó Dó Dó Ré Dó Si — a primeira frase, como escrita.
  let line: [UInt8] = [64, 64, 64, 65, 64, 62, 60, 60, 60, 62, 60, 59]

  #expect(pitches.count > 50, "a peça inteira soou: \(pitches.count) notas")
  #expect(contains(line, within: pitches, range: 57...67), "a primeira frase do Can-Can")
}

/// Rule 153 — o Capricho, com o seu Fá♯ e o baixo das duas mãos.
@Test func theEarFindsTheCaprichoMelodyAndItsAccidental() throws {
  let pitches = try heard(in: "ref-capricho")
  // Sol Sol Fá Mi | Ré Mi — a abertura, depois da anacruse.
  let line: [UInt8] = [67, 67, 65, 64, 62, 64]

  #expect(contains(line, within: pitches, range: 59...72), "a abertura do Capricho")
  #expect(pitches.contains { $0.midiNoteNumber == 66 }, "o Fá♯4 do compasso 5")
  #expect(pitches.contains { $0.midiNoteNumber <= 48 }, "o baixo da mão esquerda")
}

/// Rule 153 — a valsa é densa e pedalada, e ainda assim se ouve a harmonia.
@Test func theEarFindsTheWaltzHarmony() throws {
  let pitches = try heard(in: "ref-valsa")
  let notes = Set(pitches.map(\.midiNoteNumber))

  #expect(pitches.count > 300, "uma peça longa, densa: \(pitches.count) notas")
  // O baixo de valsa anda: Lá, Ré, Sol — a cadência de abertura.
  #expect(notes.isSuperset(of: [45, 50, 55]), "o baixo andando: \(notes.sorted().prefix(12))")
}
