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

/// Rule 151 — a sala do dono, sem ninguém tocando, não anda um passo.
///
/// Mede o que o teste de recall não mede: o quanto o ouvido INVENTA. Baixar
/// o limiar da nota esperada sem este contrapeso fez o app concluir a peça
/// sozinho, com tudo verde, enquanto o dono só olhava.
@Test func theEmptyRoomAdvancesNothing() throws {
  let url = try #require(
    Bundle.module.url(forResource: "ref-sala", withExtension: "wav", subdirectory: "Recordings"))
  let raw = try Data(contentsOf: url)
  let found = try #require(raw.range(of: Data("data".utf8)))
  let payload = raw.subdata(in: (found.upperBound + 4)..<raw.count)
  var pcm = [Int16](repeating: 0, count: payload.count / 2)
  _ = pcm.withUnsafeMutableBytes { payload.copyBytes(to: $0) }
  let samples = pcm.map { Float($0) / 32768 }

  let columns: [[UInt8]] = [[64, 48], [64], [64, 55], [65], [64], [62]]
  let ear = try NeuralEar(sampleRate: 22_050)
  ear.onsetThreshold = 0.8
  var session = ExerciseSession(
    exercise: Exercise(items: columns.map { ExerciseItem(pitches: Set($0.map(Pitch.init))) }))

  func guide() {
    var wanted = session.currentItem?.pitches ?? []
    if session.exercise.items.indices.contains(session.cursorIndex + 1) {
      wanted.formUnion(session.exercise.items[session.cursorIndex + 1].pitches)
    }
    ear.lenientPitches = wanted
  }
  guide()

  var cursor = 0
  while cursor + 2048 <= samples.count {
    for hit in ear.hear(Array(samples[cursor..<(cursor + 2048)])) {
      _ = session.press(hit.pitch, at: hit.time)
      guide()
    }
    cursor += 2048
  }

  #expect(session.cursorIndex == 0, "a sala vazia andou \(session.cursorIndex) colunas sozinha")
}

/// Rule 151 — a nota errada não vale pela esperada.
///
/// O relato do dono: tocou errado e o cursor andou assim mesmo. O ouvido
/// aberto da regra 151 é desempate, não cheque em branco — quando outra
/// tecla é claramente a que soou, a esperada não pode se servir do som
/// dela.
@Test func aWrongKeyDoesNotPassForTheExpectedOne() throws {
  let rate = 22_050.0
  func key(_ midi: UInt8, seconds: Double, from start: Double, total: Double) -> [Float] {
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
      samples[index] += 0.3 * envelope * value
    }
    return samples
  }

  // A página espera Dó4. O dedo toca Ré4 — um tom acima, o erro clássico.
  let ear = try NeuralEar(sampleRate: rate)
  ear.onsetThreshold = 0.8
  ear.lenientPitches = [Pitch(60)]

  var heard: [Pitch] = []
  let audio = key(62, seconds: 2, from: 0.4, total: 3.5)
  var cursor = 0
  while cursor + 2048 <= audio.count {
    heard += ear.hear(Array(audio[cursor..<(cursor + 2048)])).map(\.pitch)
    cursor += 2048
  }

  #expect(
    !heard.contains(Pitch(60)),
    "o Ré4 tocado virou o Dó4 esperado: \(Set(heard.map(\.midiNoteNumber)).sorted())")
}
