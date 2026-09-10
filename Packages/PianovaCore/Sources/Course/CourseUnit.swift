/// One of the sixteen units the course is divided into.
///
/// The division, the order and the concept that debuts in each unit follow the
/// sequence of an established adult method. That sequence is the pedagogy — the
/// decision that pentascales come before scales, that both clefs are read
/// before any accidental appears, that chords arrive only once intervals are
/// secure. The melodies and the exercises are written here.
public struct CourseUnit: Equatable, Sendable, Identifiable {
  /// Its place in the course, 1 to 16.
  public let number: Int

  /// The unit name shown on the trail.
  public let title: String

  /// The concept that debuts here, in one line.
  public let concept: String

  /// Stable identity for `ForEach`.
  public var id: Int { number }

  /// Creates a unit.
  /// - Parameters:
  ///   - number: Its place in the course.
  ///   - title: The unit name.
  ///   - concept: The concept that debuts here.
  public init(number: Int, title: String, concept: String) {
    self.number = number
    self.title = title
    self.concept = concept
  }

  /// How the unit is labelled on the trail.
  public var label: String { "Unidade \(number)" }
}

/// The sixteen units, in order.
public enum CourseUnits {
  /// Every unit, first to last.
  public static let all: [CourseUnit] = [
    CourseUnit(
      number: 1, title: "Introdução ao teclado",
      concept: "Postura, dedilhado, pentascale de Dó e de Sol, 2ªs e 3ªs"),
    CourseUnit(
      number: 2, title: "Orientação na pauta",
      concept: "Pauta, claves, fórmula de compasso, ligadura, legato"),
    CourseUnit(
      number: 3, title: "Reforço de leitura",
      concept: "Sol na clave de sol; Sol e Fá na clave de fá; coda"),
    CourseUnit(
      number: 4, title: "Mais leitura na pauta",
      concept: "3ªs na pauta, pausas, D.C. al Fine, acorde de Dó"),
    CourseUnit(
      number: 5, title: "Mais clave de fá",
      concept: "Dó-Ré-Mi graves, hastes, staccato, casas 1 e 2"),
    CourseUnit(
      number: 6, title: "Colcheias",
      concept: "Colcheia, frase, crescendo, fermata, anacruse"),
    CourseUnit(
      number: 7, title: "Os espaços da clave de sol",
      concept: "F-A-C-E, cruzamento de mãos, arpejo"),
    CourseUnit(
      number: 8, title: "Pentascale de Dó agudo",
      concept: "Dó a Sol agudos, imitação, ritardando"),
    CourseUnit(
      number: 9, title: "Pentascale de Sol",
      concept: "Sol em três posições, acorde de Sol"),
    CourseUnit(
      number: 10, title: "Sustenidos e bemóis",
      concept: "Semitom, tom, sustenido, bemol, bequadro"),
    CourseUnit(
      number: 11, title: "Intervalos: 4ªs, 5ªs e 6ªs",
      concept: "Quarta, quinta e sexta, bloqueadas e quebradas"),
    CourseUnit(
      number: 12, title: "Escala de Dó maior",
      concept: "Escala completa, tônica, dominante, sensível"),
    CourseUnit(
      number: 13, title: "O acorde de Sol7",
      concept: "O acorde de V7 e a substituição de dedo"),
    CourseUnit(
      number: 14, title: "Acordes primários em Dó",
      concept: "I-IV-V7, inversão, cifra"),
    CourseUnit(
      number: 15, title: "Escala de Sol maior",
      concept: "Armadura de clave"),
    CourseUnit(
      number: 16, title: "Acordes primários em Sol",
      concept: "I-IV-V7 em Sol, o acorde de Ré7"),
  ]

  /// Looks a unit up by number.
  /// - Parameter number: Its place in the course, 1 to 16.
  /// - Returns: The unit, or `nil` if the number is out of range.
  public static func unit(_ number: Int) -> CourseUnit? {
    all.first { $0.number == number }
  }
}
