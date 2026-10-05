import Foundation
import ScoreModel
import Testing

@testable import Sound

// MARK: - Rules 150-151: o microfone é um teclado, a escuta é guiada

/// A piano-like tone: fundamental plus decaying harmonics, with an attack.
private func tone(
  _ pitch: Pitch, seconds: Double, at sampleRate: Double, level: Float = 0.3,
  from start: Double = 0
) -> [Float] {
  let frequency = 440 * pow(2, (Double(pitch.midiNoteNumber) - 69) / 12)
  let count = Int(seconds * sampleRate)
  var samples = [Float](repeating: 0, count: count)
  let harmonics: [Float] = [1, 0.5, 0.33, 0.2, 0.12]

  for index in 0..<count {
    let time = Double(index) / sampleRate
    guard time >= start else { continue }
    let alive = time - start
    let envelope = Float(min(alive * 80, 1)) * Float(exp(-alive * 1.2))
    var value: Float = 0
    for (rank, weight) in harmonics.enumerated() {
      value += weight * Float(sin(2 * .pi * frequency * Double(rank + 1) * alive))
    }
    samples[index] += level * envelope * value
  }
  return samples
}

private func mixed(_ layers: [[Float]]) -> [Float] {
  let length = layers.map(\.count).max() ?? 0
  var mix = [Float](repeating: 0, count: length)
  for layer in layers {
    for index in layer.indices { mix[index] += layer[index] }
  }
  return mix
}

private let rate = 48_000.0

/// Rule 151 — a nota esperada é confirmada no espectro e vira pressionamento.
@Test func aSingleExpectedNoteIsHeard() {
  let detector = NoteDetector(sampleRate: rate)
  detector.expect([Pitch(60)], among: Pitch(48)...Pitch(84))

  let heard = detector.process(tone(Pitch(60), seconds: 0.5, at: rate))

  #expect(heard.map(\.pitch) == [Pitch(60)])
}

/// Rule 151 — um acorde esperado é ouvido nota a nota, todas.
@Test func aChordIsHeardEveryNote() {
  let detector = NoteDetector(sampleRate: rate)
  let chord: Set<Pitch> = [Pitch(60), Pitch(64), Pitch(67)]
  detector.expect(chord, among: Pitch(48)...Pitch(84))

  let audio = mixed([
    tone(Pitch(60), seconds: 0.6, at: rate),
    tone(Pitch(64), seconds: 0.6, at: rate),
    tone(Pitch(67), seconds: 0.6, at: rate),
  ])
  let heard = detector.process(audio)

  #expect(Set(heard.map(\.pitch)) == chord)
}

/// Rule 151 — a oitava de cima não tem o fundamental da esperada: não passa.
@Test func theOctaveAboveIsNotTheExpectedNote() {
  let detector = NoteDetector(sampleRate: rate)
  detector.expect([Pitch(60)], among: Pitch(48)...Pitch(84))

  let heard = detector.process(tone(Pitch(72), seconds: 0.5, at: rate))

  #expect(!heard.map(\.pitch).contains(Pitch(60)))
}

/// Rule 151 — silêncio não é nota.
@Test func silenceIsNotANote() {
  let detector = NoteDetector(sampleRate: rate)
  detector.expect([Pitch(60)], among: Pitch(48)...Pitch(84))

  let heard = detector.process([Float](repeating: 0, count: Int(rate / 2)))

  #expect(heard.isEmpty)
}

/// Rule 151 — nota não esperada com evidência forte é acusada.
@Test func aWrongNoteIsCalledOut() {
  let detector = NoteDetector(sampleRate: rate)
  detector.expect([Pitch(60)], among: Pitch(48)...Pitch(84))

  let heard = detector.process(tone(Pitch(62), seconds: 0.5, at: rate))

  #expect(heard.map(\.pitch).contains(Pitch(62)))
}

/// Rule 151 — o harmônico de uma nota certa nunca vira acusação.
@Test func harmonicsOfARightNoteAccuseNobody() {
  let detector = NoteDetector(sampleRate: rate)
  detector.expect([Pitch(60)], among: Pitch(48)...Pitch(84))

  let heard = detector.process(tone(Pitch(60), seconds: 0.6, at: rate))

  // Nada de Dó5 (harmônico 2) nem Sol5 (harmônico 3) na lista.
  #expect(!heard.map(\.pitch).contains(Pitch(72)))
  #expect(!heard.map(\.pitch).contains(Pitch(79)))
  #expect(heard.map(\.pitch) == [Pitch(60)])
}

/// Rule 151 — a nota sustentada é um pressionamento só; o re-ataque é outro.
@Test func aNewAttackIsANewPress() {
  let detector = NoteDetector(sampleRate: rate)
  detector.expect([Pitch(60)], among: Pitch(48)...Pitch(84))

  let sustained = detector.process(tone(Pitch(60), seconds: 1.0, at: rate))
  #expect(sustained.count == 1, "sustentar não repete a nota")

  let restruck = detector.process(
    mixed([
      tone(Pitch(60), seconds: 1.4, at: rate),
      tone(Pitch(60), seconds: 1.4, at: rate, from: 0.8),
    ]))
  #expect(restruck.count == 2, "o segundo ataque é outro pressionamento")
}
