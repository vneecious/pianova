import EngravingVerovio
import Foundation
import ScoreModel
import Testing

@testable import PianovaUI

/// A caixa de um compasso é o conteúdo dele na pauta — nunca o spanner que
/// parte dele e atravessa para o sistema seguinte.
///
/// Ligaduras e pedais moram no `<g>` do compasso de origem no SVG; unir
/// todos os filhos esticava a caixa do compasso até o outro sistema, e o
/// toque no sistema de baixo selecionava um compasso do de cima — o modo
/// estudo inteiro parecia quebrado.
/// A caixa de um compasso respeita a barra simples: a ligadura e o pedal
/// que partem dele não a esticam por cima do compasso vizinho.
@MainActor
@Test func measureFramesRespectTheBarline() async throws {
  var measures: [Measure] = []
  for index in 0..<4 {
    let pitch = Pitch(UInt8(64 + index * 2))
    let note = ScoreNote(
      pitches: [pitch], duration: Duration(.half, dotted: true),
      pedal: index % 2 == 0 ? .down : .up,
      slurStart: index == 0, slurStop: index == 2)
    measures.append(Measure([note]))
  }
  let score = Score(
    title: "Vizinhos", composer: "—", timeSignature: .threeFour,
    rightHand: Part(clef: .treble, measures: measures))

  let controller = EngravedPlayController()
  controller.load(score, using: Engraver())
  for _ in 0..<200 where controller.pages.isEmpty {
    try await Task.sleep(for: .milliseconds(50))
  }

  for bar in 1...3 {
    let here = try #require(controller.frameOfBar(bar, pageIndex: 0))
    let next = try #require(controller.frameOfBar(bar + 1, pageIndex: 0))
    #expect(
      here.maxX <= next.minX + 24,
      Comment(
        rawValue:
          "o compasso \(bar) (até x=\(Int(here.maxX))) invade o \(bar + 1) "
          + "(desde x=\(Int(next.minX)))"))
  }
}

@MainActor
@Test func aTapLandsOnTheBarUnderTheFinger() async throws {
  // Duas linhas forçadas: página estreita, oito compassos com ligaduras
  // cruzando a quebra e pedal em todos — o pior caso do spanner.
  var measures: [Measure] = []
  for index in 0..<8 {
    let pitch = Pitch(UInt8(60 + index))
    let even = index % 2 == 0
    let pedal: PedalMark = even ? .down : .up
    let note = ScoreNote(
      pitches: [pitch], duration: Duration(.half, dotted: true),
      pedal: pedal, slurStart: even, slurStop: !even)
    measures.append(Measure([note]))
  }
  let score = Score(
    title: "Quebra", composer: "—", timeSignature: .threeFour,
    rightHand: Part(clef: .treble, measures: measures))

  let controller = EngravedPlayController()
  controller.pageUnits = 1200
  controller.load(score, using: Engraver())
  for _ in 0..<200 where controller.pages.isEmpty {
    try await Task.sleep(for: .milliseconds(50))
  }

  let page = try #require(controller.pages.first)
  try #require(page.systems.count >= 2, Comment(rawValue: "o caso precisa de duas linhas"))

  // Um toque no meio do segundo sistema tem que achar um compasso que MORA
  // no segundo sistema, nunca um do primeiro.
  let second = page.systems[1].frame
  let point = CGPoint(x: page.size.width * 0.3, y: second.midY)
  let hit = try #require(controller.bar(exactlyAtPagePoint: point, pageIndex: 0))
  let firstSystemBars = Set(1...4)
  #expect(
    !firstSystemBars.contains(hit),
    Comment(rawValue: "o toque no sistema 2 achou o compasso \(hit), do sistema 1"))
}
