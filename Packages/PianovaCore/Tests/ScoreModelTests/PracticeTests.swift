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

// MARK: - Rule 105: isolar um trecho

/// Um trecho vira uma peça com só aqueles compassos.
@Test func aRangeBecomesItsOwnPiece() {
  let passage = fourBars().extracting(PracticeRange(first: 2, last: 3))

  #expect(passage.rightHand.measures.count == 2)
  #expect(passage.rightHand.measures.first?.notes.first?.pitches.first?.midiNoteNumber == 61)
}

/// A ordem em que os compassos são tocados não importa.
@Test func theRangeSortsItself() {
  let backwards = PracticeRange(first: 4, last: 2)

  #expect(backwards.first == 2)
  #expect(backwards.last == 4)
  #expect(backwards.count == 3)
}

/// Sem trecho, é a peça inteira.
@Test func noRangeMeansTheWholePiece() {
  #expect(fourBars().extracting(nil).rightHand.measures.count == 4)
}

/// Um trecho que passa do fim para no fim, em vez de estourar.
@Test func aRangeIsClampedToThePiece() {
  let passage = fourBars().extracting(PracticeRange(first: 3, last: 99))

  #expect(passage.rightHand.measures.count == 2)
}

// MARK: - Rule 106: uma mão de cada vez

/// A mão direita sozinha é uma peça de uma pauta.
@Test func therightHandAloneIsOneStaff() {
  let passage = fourBars().extracting(nil, hands: .right)

  #expect(passage.isTwoHanded == false)
  #expect(passage.rightHand.clef == .treble)
}

/// A esquerda sozinha também — e continua sendo lida em clave de fá.
///
/// Sem isso, estudar a mão esquerda mostraria uma pauta vazia: ela é a segunda
/// pauta, e uma peça precisa de uma primeira.
@Test func theLeftHandAloneIsAlsoAPiece() {
  let passage = fourBars().extracting(nil, hands: .left)

  #expect(passage.isTwoHanded == false)
  #expect(passage.rightHand.clef == .bass, "a mão que sobra é a que se lê")
  #expect(passage.rightHand.measures.first?.notes.first?.pitches.first?.midiNoteNumber == 48)
}

/// Mão e trecho se combinam.
@Test func handAndRangeCombine() {
  let passage = fourBars().extracting(PracticeRange(first: 2, last: 2), hands: .left)

  #expect(passage.rightHand.measures.count == 1)
  #expect(passage.rightHand.measures.first?.notes.first?.pitches.first?.midiNoteNumber == 49)
}

// MARK: - A anacruse

/// O compasso 1 é o primeiro compasso cheio, mesmo com anacruse antes.
///
/// Os números são os que o usuário vê na página; se o corte contasse posições
/// em vez de números, estudar o compasso 2 traria o 1.
@Test func barNumbersSurviveAnUpbeat() {
  let passage = fourBars(pickup: true).extracting(PracticeRange(first: 1, last: 1))

  #expect(passage.rightHand.measures.count == 1)
  #expect(passage.rightHand.measures.first?.notes.first?.pitches.first?.midiNoteNumber == 60)
}

/// Um trecho que não começa no início não tem anacruse.
@Test func aPassageInTheMiddleHasNoUpbeat() {
  let passage = fourBars(pickup: true).extracting(PracticeRange(first: 2, last: 3))

  #expect(passage.hasPickup == false)
  #expect(passage.isWellFormed, "sem anacruse, todos os compassos devem fechar")
}

/// Quantos compassos há para escolher, sem contar a anacruse.
@Test func theBarCountIgnoresTheUpbeat() {
  #expect(fourBars().measureCount == 4)
  #expect(fourBars(pickup: true).measureCount == 4)
}

/// Como o trecho se apresenta ao usuário.
@Test func aRangeSaysWhatItIs() {
  #expect(PracticeRange(first: 3, last: 3).label == "Compasso 3")
  #expect(PracticeRange(first: 3, last: 6).label == "Compassos 3–6")
}
