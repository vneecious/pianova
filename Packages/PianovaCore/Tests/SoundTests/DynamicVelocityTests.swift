import ScoreModel
import Testing

@testable import Sound

// MARK: - Rule 141: cada marca escrita tem sua força

/// Rule 141 — p toca mais piano que mf, que toca mais piano que f.
@Test func writtenDynamicsOrderTheirVelocities() {
  let p = ScorePlayer.velocity(for: "p")
  let mf = ScorePlayer.velocity(for: "mf")
  let f = ScorePlayer.velocity(for: "f")

  #expect(p < mf)
  #expect(mf < f)
}

/// Rule 141 — sem marca, o toque médio de sempre.
@Test func noMarkPlaysTheUsualTouch() {
  #expect(ScorePlayer.velocity(for: nil) == 74)
}

// MARK: - Rule 141: cresc. é rampa

/// Rule 141 — com alvo escrito, a rampa termina exatamente nele.
@Test func aCrescendoRampsToTheNextMark() {
  let score = Score(
    title: "Com alvo", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(pitches: [Pitch(60)], duration: Duration(.quarter), dynamic: "p"),
          ScoreNote(pitches: [Pitch(62)], duration: Duration(.quarter), words: "cresc."),
          ScoreNote(Pitch(64), .quarter),
          ScoreNote(Pitch(65), .quarter),
        ]),
        Measure([
          ScoreNote(pitches: [Pitch(67)], duration: Duration(.whole), dynamic: "f")
        ]),
      ]))

  let touches = ScorePlayer.touches(for: score)

  #expect(touches[0] == ScorePlayer.velocity(for: "p"))
  #expect(touches[4] == ScorePlayer.velocity(for: "f"))
  #expect(touches[1] < touches[2] && touches[2] < touches[3], "a rampa sobe degrau a degrau")
  #expect(touches[3] < touches[4])
}

/// Rule 141 — sem alvo, cresce com moderação e para de crescer.
@Test func aCrescendoWithoutTargetGrowsModestly() {
  var notes: [ScoreNote] = [
    ScoreNote(pitches: [Pitch(60)], duration: Duration(.quarter), words: "cresc.")
  ]
  for index in 1..<24 {
    notes.append(ScoreNote(Pitch(UInt8(60 + index % 5)), .quarter))
  }
  let score = Score(
    title: "Sem alvo", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: (0..<6).map { bar in Measure(Array(notes[(bar * 4)..<(bar * 4 + 4)])) }))

  let touches = ScorePlayer.touches(for: score)

  #expect(touches[0] == ScorePlayer.velocity(for: nil))
  let peak = touches.max() ?? 0
  #expect(peak <= ScorePlayer.velocity(for: nil) + 16, "sem alvo, no máximo um degrau e meio")
  #expect(touches.last == peak, "depois da rampa, segura o novo patamar")
  #expect(touches[1] > touches[0], "mas cresce de verdade")
}

// MARK: - Rule 139: a agenda do Ouvir

/// Rule 139 — sem ornamento, cada coluna cai exatamente no seu tempo
/// acumulado: o grid é a soma dos valores escritos.
@Test func theScheduleLandsColumnsOnTheGrid() {
  let score = Score(
    title: "Grid", composer: "—",
    timeSignature: .threeFour,
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(Pitch(60), .quarter), ScoreNote(Pitch(62), .quarter),
          ScoreNote(Pitch(64), .quarter),
        ])
      ]))

  let notes = ScorePlayer.schedule(
    for: score, order: [0, 1, 2], tempo: 120, hands: .both)

  #expect(notes.map(\.time) == [0.0, 0.5, 1.0])
  #expect(notes.map(\.column) == [0, 1, 2])
}

/// Rule 139 — a grace soa ANTES do tempo e a nota decorada não se move.
@Test func gracesSoundBeforeTheirBeat() {
  let score = Score(
    title: "Apojatura", composer: "—",
    timeSignature: .threeFour,
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(Pitch(60), .quarter),
          ScoreNote(
            pitches: [Pitch(64)], duration: Duration(.quarter),
            graces: [GraceNote(pitch: Pitch(64)), GraceNote(pitch: Pitch(65))]),
          ScoreNote(Pitch(67), .quarter),
        ])
      ]))

  let notes = ScorePlayer.schedule(
    for: score, order: [0, 1, 2], tempo: 120, hands: .both)

  // As colunas seguem no grid exato.
  let mains = notes.filter { $0.column != nil }
  #expect(mains.map(\.time) == [0.0, 0.5, 1.0])

  // As duas graces soam antes do tempo da decorada, em ordem, depois da
  // coluna anterior.
  let graces = notes.filter { $0.column == nil }
  #expect(graces.count == 2)
  #expect(graces.allSatisfy { $0.time > 0.0 && $0.time < 0.5 })
  #expect(graces[0].time < graces[1].time)
  #expect(graces[0].pitches == [Pitch(64)])
  #expect(graces[1].pitches == [Pitch(65)])
}

/// Rule 139 — só a mão esquerda em estudo: a grace da direita não soa.
@Test func leftHandOnlySkipsTheGraces() {
  let score = Score(
    title: "Só esquerda", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure([
          ScoreNote(
            pitches: [Pitch(72)], duration: Duration(.whole),
            graces: [GraceNote(pitch: Pitch(74))])
        ])
      ]),
    leftHand: Part(
      clef: .bass,
      measures: [Measure([ScoreNote(Pitch(48), .whole)])]))

  let notes = ScorePlayer.schedule(for: score, order: [0], tempo: 60, hands: .left)

  #expect(notes.filter { $0.column == nil }.isEmpty, "ornamento é da direita")
  #expect(notes.count == 1)
  #expect(notes[0].pitches == [Pitch(48)])
}
