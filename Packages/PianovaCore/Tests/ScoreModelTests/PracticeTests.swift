import Testing

@testable import ScoreModel

/// Quatro compassos, duas mãos, sem anacruse.
private func fourBars(pickup: Bool = false) -> Score {
  func bar(_ pitch: Int) -> Measure {
    Measure([ScoreNote(Pitch(UInt8(pitch)), .whole)])
  }

  let right = (0..<4).map { bar(60 + $0) }
  let left = (0..<4).map { bar(48 + $0) }

  return Score(
    title: "Quatro", composer: "—",
    rightHand: Part(clef: .treble, measures: pickup ? [bar(67)] + right : right),
    leftHand: Part(clef: .bass, measures: pickup ? [bar(55)] + left : left),
    hasPickup: pickup)
}

// MARK: - Rule 110: estudar restringe o que é avaliado

/// Rule 110 — um trecho diz quais compassos contam, e o resto da peça segue lá.
@Test func aPassageSaysWhichBarsAreJudged() {
  let passage = PracticeRange(first: 3, last: 5)

  #expect(passage.judges(bar: 3))
  #expect(passage.judges(bar: 4))
  #expect(passage.judges(bar: 5))
  #expect(passage.judges(bar: 2) == false)
  #expect(passage.judges(bar: 6) == false)
}

/// Rule 111 — a mão em estudo é avaliada, a outra não.
@Test func onlyTheHandInStudyIsJudged() {
  #expect(PracticeHands.right.judges(staff: 1))
  #expect(PracticeHands.right.judges(staff: 2) == false)
  #expect(PracticeHands.left.judges(staff: 2))
  #expect(PracticeHands.left.judges(staff: 1) == false)
}

/// Rule 111 — com as duas mãos, tudo conta.
@Test func bothHandsJudgeEverything() {
  #expect(PracticeHands.both.judges(staff: 1))
  #expect(PracticeHands.both.judges(staff: 2))
}

/// Rule 111 — a mão fora de estudo é esmaecida, e é a outra.
///
/// Esmaecida e não removida: ela é a referência do que esta mão tem que
/// encaixar, e tirá-la tira o motivo do trecho.
@Test func theHandOutOfStudyIsTheOneFaded() {
  #expect(PracticeHands.right.quietStaff == 2)
  #expect(PracticeHands.left.quietStaff == 1)
  #expect(PracticeHands.both.quietStaff == nil)
}

// MARK: - Rule 113: o preview toca o que está em estudo

/// Rule 113 — sem trecho e com as duas mãos, o estudo é a peça inteira.
@Test func withNothingChosenTheStudyIsTheWholePiece() {
  let study = Study(range: nil, hands: .both)

  #expect(study.isWholePiece)
  #expect(study.listenTitle == "Ouvir a peça")
}

/// Rule 113 — o botão diz o que vai tocar, porque é o que vai tocar.
@Test func theListenButtonNamesWhatItWillPlay() {
  #expect(
    Study(range: PracticeRange(first: 3, last: 3), hands: .both).listenTitle
      == "Ouvir o compasso 3")
  #expect(
    Study(range: PracticeRange(first: 3, last: 5), hands: .both).listenTitle
      == "Ouvir os compassos 3–5")
  #expect(Study(range: nil, hands: .right).listenTitle == "Ouvir a mão direita")
  #expect(
    Study(range: PracticeRange(first: 3, last: 5), hands: .left).listenTitle
      == "Ouvir os compassos 3–5, mão esquerda")
}

/// Uma mão só continua sendo estudo mesmo sem trecho escolhido.
@Test func aHandAloneIsAlreadyAStudy() {
  #expect(Study(range: nil, hands: .left).isWholePiece == false)
}

// MARK: - Rule 106: um trecho é contíguo

/// Rule 106 — marcar o 1 e tocar no 7 estuda tudo entre eles.
///
/// Estudar o 1 e o 7 soltos não é estudo de nada: o que se treina é a passagem
/// de um compasso ao seguinte, e ela só existe entre vizinhos.
@Test func extendingASelectionFillsTheGap() {
  let passage = PracticeRange(first: 1, last: 7)

  #expect(passage.count == 7)
  #expect((1...7).allSatisfy(passage.judges(bar:)))
}

/// Rule 106 — estender para trás dá o mesmo trecho.
@Test func aSelectionDoesNotCareWhichEndCameFirst() {
  #expect(PracticeRange(first: 7, last: 1) == PracticeRange(first: 1, last: 7))
}

// MARK: - Rule 113: o preview toca sem sair da peça

/// Rule 113 — o trecho é um pedaço das colunas da peça, e não outra peça.
///
/// É o que mantém o destaque e o scroll no lugar: o preview anuncia a coluna em
/// que está, e essa coluna tem de ser a mesma que está gravada na tela.
@Test func aPassageIsARangeOfTheSameColumns() {
  let score = fourBars()
  let bounds = score.columns(in: PracticeRange(first: 2, last: 3))

  #expect(bounds.allSatisfy { (2...3).contains(score.measureNumber(atColumn: $0)) })
  #expect(bounds.isEmpty == false)
}

/// Rule 113 — sem trecho escolhido, o preview percorre a peça inteira.
@Test func withoutAPassageEveryColumnPlays() {
  let score = fourBars()

  #expect(score.columns(in: nil) == score.columns.indices.startIndex..<score.columns.count)
}

/// Um trecho fora da peça não devolve coluna nenhuma, em vez de estourar.
@Test func aPassagePastTheEndIsEmpty() {
  #expect(fourBars().columns(in: PracticeRange(first: 40, last: 50)).isEmpty)
}

/// Rule 111 — a mão fora de estudo não soa no preview, mas o tempo dela passa.
@Test func onlyTheHandInStudySounds() {
  let score = fourBars()
  let column = score.columns[0]

  #expect(column.pitches(for: .both).count == 2)
  #expect(column.pitches(for: .right) == column.upper)
  #expect(column.pitches(for: .left) == column.lower)
}

// MARK: - Rule 108: o modo estudo mostra só o trecho

/// Rule 108 — um trecho vira uma peça com só aqueles compassos.
@Test func aRangeBecomesItsOwnPiece() {
  let passage = fourBars().extracting(PracticeRange(first: 2, last: 3))

  #expect(passage.rightHand.measures.count == 2)
  #expect(passage.leftHand?.measures.count == 2)
  #expect(passage.rightHand.measures.first?.notes.first?.pitches == [Pitch(61)])
}

/// Rule 109 — o recorte nunca corta uma mão: as duas ficam na pauta.
///
/// A mão em descanso é esmaecida no desenho, não removida do recorte — o
/// esmaecido é o único sinal de mão em descanso, e remover seria outro sinal.
@Test func extractingKeepsBothHands() {
  let passage = fourBars().extracting(PracticeRange(first: 2, last: 2))

  #expect(passage.leftHand != nil)
}

/// Sem trecho, a peça volta inteira.
@Test func extractingNothingGivesTheWholePiece() {
  #expect(fourBars().extracting(nil).rightHand.measures.count == 4)
}

/// Um trecho que passa do fim é cortado no fim.
@Test func aRangePastTheEndIsClipped() {
  let passage = fourBars().extracting(PracticeRange(first: 3, last: 99))

  #expect(passage.rightHand.measures.count == 2)
}

/// Rule 108 — os números de compasso são os que o jogador vê, com anacruse.
///
/// O compasso 1 é o primeiro compasso cheio; a anacruse não é numerada. Cortar
/// por posição em vez de por número estudaria o compasso errado.
@Test func extractingCountsBarsTheWayThePlayerSees() {
  let passage = fourBars(pickup: true).extracting(PracticeRange(first: 1, last: 1))

  #expect(passage.rightHand.measures.count == 1)
  #expect(passage.rightHand.measures.first?.notes.first?.pitches == [Pitch(60)])
  #expect(passage.hasPickup == false, "um trecho do meio não tem anacruse")
}
