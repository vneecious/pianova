import Foundation
import ScoreModel
import Testing

@testable import Sound

// MARK: - Rule 153: o ouvido é uma rede neural

private let rate = 48_000.0

/// A piano-ish tone: fundamental plus decaying harmonics, with an attack.
private func key(_ midi: UInt8, seconds: Double, from start: Double, total: Double) -> [Float] {
  let frequency = 440 * pow(2, (Double(midi) - 69) / 12)
  var samples = [Float](repeating: 0, count: Int(total * rate))
  let harmonics: [Float] = [1, 0.5, 0.33, 0.2, 0.12]
  for index in samples.indices {
    let time = Double(index) / rate
    guard time >= start, time - start <= seconds else { continue }
    let alive = time - start
    let envelope = Float(min(alive * 80, 1)) * Float(exp(-alive * 1.1))
    var value: Float = 0
    for (rank, weight) in harmonics.enumerated() {
      value += weight * Float(sin(2 * .pi * frequency * Double(rank + 1) * alive))
    }
    samples[index] += 0.25 * envelope * value
  }
  return samples
}

private func mix(_ layers: [[Float]]) -> [Float] {
  var out = [Float](repeating: 0, count: layers.map(\.count).max() ?? 0)
  for layer in layers {
    for index in layer.indices { out[index] += layer[index] }
  }
  return out
}

/// Rule 153 — o modelo carrega do pacote, pronto para ouvir.
@Test func theNeuralEarLoadsItsModel() throws {
  let ear = try NeuralEar(sampleRate: rate)
  #expect(ear.isReady)
}

/// Rule 153 — uma tríade de Dó é ouvida nota a nota, as três.
@Test func theNeuralEarHearsAChord() throws {
  let ear = try NeuralEar(sampleRate: rate)
  let audio = mix([
    key(60, seconds: 2, from: 0.3, total: 3),
    key(64, seconds: 2, from: 0.3, total: 3),
    key(67, seconds: 2, from: 0.3, total: 3),
  ])

  let heard = Set(ear.listen(to: audio).map(\.pitch.midiNoteNumber))

  #expect(heard.isSuperset(of: [60, 64, 67]), "a tríade inteira, ouvida: \(heard.sorted())")
}

/// Rule 153 — as duas mãos ao mesmo tempo: baixo e tríade acima.
@Test func theNeuralEarHearsBothHands() throws {
  let ear = try NeuralEar(sampleRate: rate)
  let audio = mix([
    key(48, seconds: 2, from: 0.3, total: 3),
    key(55, seconds: 2, from: 0.3, total: 3),
    key(64, seconds: 2, from: 0.35, total: 3),
    key(67, seconds: 2, from: 0.35, total: 3),
  ])

  let heard = Set(ear.listen(to: audio).map(\.pitch.midiNoteNumber))

  #expect(heard.contains(48), "o baixo: \(heard.sorted())")
  #expect(heard.isSuperset(of: [64, 67]), "a mão direita: \(heard.sorted())")
}

/// Rule 153 — silêncio não inventa nota.
@Test func theNeuralEarHearsNothingInSilence() throws {
  let ear = try NeuralEar(sampleRate: rate)
  #expect(ear.listen(to: [Float](repeating: 0, count: Int(rate * 3))).isEmpty)
}

/// Rule 153 — ao vivo: o áudio chega em pedacinhos e a nota sai uma vez só.
@Test func theNeuralEarStreamsWithoutRepeating() throws {
  let ear = try NeuralEar(sampleRate: rate)
  let audio = mix([
    key(60, seconds: 2, from: 0.5, total: 4),
    key(64, seconds: 2, from: 0.5, total: 4),
    key(67, seconds: 2, from: 0.5, total: 4),
  ])

  var heard: [NeuralEar.Heard] = []
  var cursor = 0
  let chunk = 2048
  while cursor + chunk <= audio.count {
    heard += ear.hear(Array(audio[cursor..<(cursor + chunk)]))
    cursor += chunk
  }

  let pitches = heard.map(\.pitch.midiNoteNumber)
  #expect(Set(pitches).isSuperset(of: [60, 64, 67]), "a tríade ao vivo: \(Set(pitches).sorted())")
  #expect(pitches.filter { $0 == 60 }.count <= 2, "o Dó não se repete sem parar")
}
