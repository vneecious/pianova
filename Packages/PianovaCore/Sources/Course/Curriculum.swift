import ScoreModel

/// The ordered course: sixteen units, each closing on technique and theory.
///
/// The spine is the unit sequence of an established adult piano method — which
/// concept arrives when, and in which order. That sequence is the pedagogy, and
/// it is worth following: pentascales before scales, both clefs before any
/// accidental, intervals secure before chords, chords before lead sheets.
///
/// Two honest boundaries:
///
/// - The order of the units and the concept each one introduces follow the
///   method. Everything written here — the melodies, the exercises, the
///   wording — is public domain or original to this repository. No arrangement
///   or copyrighted piece is reproduced.
/// - Where the method uses a piece still in copyright, the trail substitutes a
///   public domain piece of the same difficulty.
public enum Course {
  /// The lessons, first to last.
  public static let lessons: [Lesson] =
    unit1 + unit2 + unit3 + unit4 + unit5 + unit6 + unit7 + unit8
    + unit9 + unit10 + unit11 + unit12 + unit13 + unit14 + unit15 + unit16

  /// Lessons of one unit, in order.
  /// - Parameter unit: The unit number, 1 to 16.
  /// - Returns: Its lessons.
  public static func lessons(in unit: Int) -> [Lesson] {
    lessons.filter { $0.unit == unit }
  }

  /// Which unit a piece first appears in, or `nil` if the course never uses it.
  ///
  /// This is what tells the repertoire screen how hard a piece is: its place in
  /// the course *is* its difficulty, and no separate grading is needed.
  /// - Parameter score: The piece to look for.
  /// - Returns: The unit number, or `nil` if it is not in the course.
  public static func unit(playing score: Score) -> Int? {
    for lesson in lessons {
      for step in lesson.steps {
        guard case .song(let scheduled) = step, scheduled.title == score.title else { continue }
        return lesson.unit
      }
    }
    return nil
  }

  /// Every piece the course schedules, easiest first.
  ///
  /// Ordered by the unit that introduces each one, which is the order the
  /// course itself considers to run from simple to hard.
  public static var repertoire: [Score] {
    Songs.all
      .map { (score: $0, unit: unit(playing: $0) ?? Int.max) }
      .sorted { ($0.unit, $0.score.title) < ($1.unit, $1.score.title) }
      .map(\.score)
  }

  /// Teaching pages read by the time a lesson runs, including its own.
  /// - Parameter lesson: The lesson being taken.
  /// - Returns: Identifiers of every page taught up to and including it.
  public static func pagesTaught(upTo lesson: Lesson) -> Set<String> {
    guard let index = lessons.firstIndex(where: { $0.id == lesson.id }) else {
      return Set(lesson.readingIDs)
    }
    return Set(lessons.prefix(index + 1).flatMap(\.readingIDs))
  }

  /// Questions a lesson may ask, in the order it should prefer them.
  ///
  /// Only questions whose page has already been read: nothing is asked before
  /// it is taught. The lesson's own pages come first, and pages from earlier
  /// lessons follow as review.
  /// - Parameter lesson: The lesson being taken.
  /// - Returns: The eligible questions, own pages first.
  public static func eligibleQuestions(for lesson: Lesson) -> [TheoryQuestion] {
    let taught = pagesTaught(upTo: lesson)
    let own = Set(lesson.readingIDs)

    let eligible = TheoryBank.all.filter { taught.contains($0.noteID) }
    return eligible.filter { own.contains($0.noteID) }
      + eligible.filter { !own.contains($0.noteID) }
  }

  // MARK: - Unit 1. Introdução ao teclado

  private static let unit1: [Lesson] = [
    Lesson(
      id: "u1-keyboard", unit: 1,
      title: "Achar-se no teclado",
      subtitle: "Postura, e os grupos de duas e três teclas pretas",
      steps: [
        .reading(noteIDs: ["n-keyboard"]),
        .theory(count: 3),
        .technique(Technique.blackKeyGroups),
      ]),
    Lesson(
      id: "u1-fingers", unit: 1,
      title: "Os cinco dedos",
      subtitle: "Numeração das mãos, e uma melodia guiada por dedos",
      steps: [
        .reading(noteIDs: ["n-fingers"]),
        .theory(count: 3),
        .technique(Technique.amazingGrace),
      ]),
    Lesson(
      id: "u1-rhythm", unit: 1,
      title: "Pulso e figuras",
      subtitle: "Semínima, mínima, mínima pontuada e semibreve",
      steps: [
        .technique(Technique.musicAlphabet),
        .theory(count: 3),
        .technique(Technique.camptownRaces),
      ]),
    Lesson(
      id: "u1-cde", unit: 1,
      title: "Dó-Ré-Mi",
      subtitle: "As teclas achadas pelas pretas, e o intervalo de terça",
      steps: [
        .technique(Technique.cdeGroups),
        .technique(Technique.merrilyCDE),
        .technique(Technique.thirdInterval),
      ]),
    Lesson(
      id: "u1-fga", unit: 1,
      title: "Fá-Sol-Lá e transposição",
      subtitle: "A mesma melodia começando noutra tecla",
      steps: [
        .technique(Technique.fgaGroups),
        .technique(Technique.merrilyFGA),
        .theory(count: 3),
      ]),
    Lesson(
      id: "u1-close", unit: 1,
      title: "Pentascale de Dó",
      subtitle: "Cinco dedos, terças, e o Hino à Alegria",
      steps: [
        .technique(Technique.cPentascale),
        .technique(Technique.pentascaleThirds),
        .technique(Technique.roundHand),
        .technique(Technique.odeToJoyPentascale),
        .theory(count: 4),
      ]),
  ]

  // MARK: - Unit 2. Orientação na pauta

  private static let unit2: [Lesson] = [
    Lesson(
      id: "u2-staff", unit: 2,
      title: "A pauta",
      subtitle: "Cinco linhas e quatro espaços",
      steps: [
        .reading(noteIDs: ["n-staff"]),
        .theory(count: 4),
        .cards(clef: .treble, range: 60...65, count: 6),
        .cards(clef: .bass, range: 57...60, count: 6),
      ]),
    Lesson(
      id: "u2-clefs", unit: 2,
      title: "As claves",
      subtitle: "Quem decide qual nota é qual",
      steps: [
        .reading(noteIDs: ["n-clefs"]),
        .theory(count: 4),
        .cards(clef: .bass, range: 55...60, count: 8),
      ]),
    Lesson(
      id: "u2-middle-c", unit: 2,
      title: "O Dó central",
      subtitle: "A mesma tecla, nas duas claves",
      steps: [
        .reading(noteIDs: ["n-middle-c"]),
        .theory(count: 4),
        .cards(clef: .treble, range: 60...65, count: 8),
        .play(clef: .bass, range: 55...60, length: 6),
      ]),
    Lesson(
      id: "u2-close", unit: 2,
      title: "Compasso e ligadura",
      subtitle: "Contar antes de tocar",
      steps: [
        .reading(noteIDs: ["n-bars"]),
        .cards(clef: .bass, range: 55...60, count: 6),
        .song(Songs.lightlyRow),
        .technique(Technique.walkingFingers),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 3. Reforço de leitura

  private static let unit3: [Lesson] = [
    Lesson(
      id: "u3-treble-g", unit: 3,
      title: "O Sol da clave de sol",
      subtitle: "A linha que dá nome à clave",
      steps: [
        .cards(clef: .treble, range: 60...67, count: 10),
        .ear(clef: .treble, range: 60...67, count: 6),
        .play(clef: .treble, range: 60...67, length: 8),
      ]),
    Lesson(
      id: "u3-close", unit: 3,
      title: "Sol e Fá na clave de fá",
      subtitle: "Descendo a partir do Dó central",
      steps: [
        .reading(noteIDs: ["n-ledger"]),
        .cards(clef: .bass, range: 53...60, count: 10),
        .song(Songs.odeToJoy),
        .technique(Technique.threeTempos),
        .theory(count: 4),
      ]),
  ]

  // MARK: - Unit 4. Mais leitura na pauta

  private static let unit4: [Lesson] = [
    Lesson(
      id: "u4-thirds", unit: 4,
      title: "Terças na pauta",
      subtitle: "Linha para linha, espaço para espaço",
      steps: [
        .cards(clef: .treble, range: 60...69, count: 10),
        .cards(clef: .bass, range: 53...60, count: 8),
        .harmony(clef: .treble, range: 60...69, length: 6, voices: 2),
      ]),
    Lesson(
      id: "u4-values", unit: 4,
      title: "Figuras",
      subtitle: "Semibreve, mínima, semínima",
      steps: [
        .reading(noteIDs: ["n-values"]),
        .theory(count: 5),
        .play(clef: .bass, range: 53...60, length: 6),
      ]),
    Lesson(
      id: "u4-rests", unit: 4,
      title: "Pausas",
      subtitle: "O silêncio também se escreve",
      steps: [
        .reading(noteIDs: ["n-rests"]),
        .theory(count: 5),
      ]),
    Lesson(
      id: "u4-close", unit: 4,
      title: "O acorde de Dó",
      subtitle: "Três notas de uma vez",
      steps: [
        .harmony(clef: .bass, range: 48...60, length: 5, voices: 3),
        .song(Songs.newWorldTheme),
        .technique(Technique.brokenThirds),
        .theory(count: 4),
      ]),
  ]

  // MARK: - Unit 5. Mais clave de fá

  private static let unit5: [Lesson] = [
    Lesson(
      id: "u5-bass-cde", unit: 5,
      title: "Dó, Ré e Mi graves",
      subtitle: "A mão esquerda ganha sua própria região",
      steps: [
        .cards(clef: .bass, range: 48...55, count: 10),
        .ear(clef: .bass, range: 48...55, count: 6),
        .song(Songs.rowYourBoat),
      ]),
    Lesson(
      id: "u5-close", unit: 5,
      title: "Ligado e destacado",
      subtitle: "Staccato encurta o som, não o tempo",
      steps: [
        .reading(noteIDs: ["n-articulation"]),
        .play(clef: .bass, range: 48...60, length: 8),
        .song(Songs.londonBridge),
        .technique(Technique.contraryMotion),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 6. Colcheias

  private static let unit6: [Lesson] = [
    Lesson(
      id: "u6-eighths", unit: 6,
      title: "A colcheia",
      subtitle: "Duas para cada tempo",
      steps: [
        .reading(noteIDs: ["n-dot-tie"]),
        .theory(count: 5),
        .rhythm(
          clef: .treble,
          pattern: [
            RhythmStepNote(Pitch(60), .eighth), RhythmStepNote(Pitch(62), .eighth),
            RhythmStepNote(Pitch(64), .quarter), RhythmStepNote(Pitch(65), .quarter),
            RhythmStepNote(Pitch(67), .quarter),
            RhythmStepNote(Pitch(67), .eighth), RhythmStepNote(Pitch(65), .eighth),
            RhythmStepNote(Pitch(64), .quarter), RhythmStepNote(Pitch(62), .quarter),
            RhythmStepNote(Pitch(60), .quarter),
          ],
          tempo: 66, beatsPerBar: 4),
      ]),
    Lesson(
      id: "u6-anacrusis", unit: 6,
      title: "Anacruse e fermata",
      subtitle: "Quando a música começa antes do compasso",
      steps: [
        .cards(clef: .bass, range: 48...55, count: 8),
        .song(Songs.happyBirthday),
        .song(Songs.taps),
      ]),
    Lesson(
      id: "u6-close", unit: 6,
      title: "Frase e crescendo",
      subtitle: "A música respira",
      steps: [
        .play(clef: .bass, range: 48...60, length: 8),
        .technique(Technique.eighthNoteDrill),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 7. Os espaços da clave de sol

  private static let unit7: [Lesson] = [
    Lesson(
      id: "u7-face", unit: 7,
      title: "F-A-C-E",
      subtitle: "Os quatro espaços da clave de sol",
      steps: [
        .cards(clef: .treble, range: 65...72, count: 12),
        .ear(clef: .treble, range: 65...72, count: 6),
        .cards(clef: .bass, range: 48...57, count: 8),
      ]),
    Lesson(
      id: "u7-close", unit: 7,
      title: "Arpejo e cruzamento",
      subtitle: "O acorde apresentado no tempo",
      steps: [
        .reading(noteIDs: ["c-arpeggio"]),
        .song(Songs.reveille),
        .song(Songs.auraLee),
        .technique(Technique.crossHandArpeggio),
        .theory(count: 4),
      ]),
  ]

  // MARK: - Unit 8. Pentascale de Dó agudo

  private static let unit8: [Lesson] = [
    Lesson(
      id: "u8-upper-c", unit: 8,
      title: "Dó a Sol, uma oitava acima",
      subtitle: "A mesma forma, lida mais alto",
      steps: [
        .cards(clef: .treble, range: 72...79, count: 10),
        .cards(clef: .bass, range: 48...57, count: 8),
        .song(Songs.whenTheSaints),
      ]),
    Lesson(
      id: "u8-close", unit: 8,
      title: "Imitação e ritardando",
      subtitle: "Uma mão responde à outra",
      steps: [
        .reading(noteIDs: ["i-what"]),
        .song(Songs.michaelRow),
        .technique(Technique.imitation),
        .theory(count: 4),
      ]),
  ]

  // MARK: - Unit 9. Pentascale de Sol

  private static let unit9: [Lesson] = [
    Lesson(
      id: "u9-g-pentascale", unit: 9,
      title: "A posição de Sol",
      subtitle: "A mesma mão, cinco teclas adiante",
      steps: [
        .cards(clef: .treble, range: 67...74, count: 10),
        .cards(clef: .bass, range: 48...60, count: 8),
        .song(Songs.twinkleInG),
      ]),
    Lesson(
      id: "u9-close", unit: 9,
      title: "Transpor",
      subtitle: "A melodia não muda, a leitura muda",
      steps: [
        .reading(noteIDs: ["s-what"]),
        .play(clef: .bass, range: 48...60, length: 8),
        .song(Songs.odeToJoyInG),
        .technique(Technique.fingerFanfare),
        .theory(count: 4),
      ]),
  ]

  // MARK: - Unit 10. Sustenidos e bemóis

  private static let unit10: [Lesson] = [
    Lesson(
      id: "u10-half-steps", unit: 10,
      title: "Tom e semitom",
      subtitle: "A menor distância do teclado",
      steps: [
        .reading(noteIDs: ["i-tone-semitone"]),
        .theory(count: 5),
        .chromatic(clef: .treble, range: 60...72, length: 6),
      ]),
    Lesson(
      id: "u10-accidentals", unit: 10,
      title: "Sustenido, bemol e bequadro",
      subtitle: "Os sinais que alteram a nota",
      steps: [
        .reading(noteIDs: ["s-accidentals"]),
        .theory(count: 5),
        .chromatic(clef: .bass, range: 48...60, length: 6),
        .song(Songs.greensleeves),
      ]),
    Lesson(
      id: "u10-close", unit: 10,
      title: "O desenho do pentascale maior",
      subtitle: "Tom, tom, semitom, tom",
      steps: [
        .chromatic(clef: .treble, range: 62...74, length: 8),
        .technique(Technique.wholeAndHalfSteps),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 11. Intervalos: 4ªs, 5ªs e 6ªs

  private static let unit11: [Lesson] = [
    Lesson(
      id: "u11-fourths-fifths", unit: 11,
      title: "Quartas e quintas",
      subtitle: "Saltos que a mão alcança sem se mexer",
      steps: [
        .reading(noteIDs: ["i-melodic-harmonic"]),
        .theory(count: 5),
        .harmony(clef: .treble, range: 60...72, length: 6, voices: 2),
        .ear(clef: .bass, range: 48...60, count: 6),
        .song(Songs.nobodyKnows),
      ]),
    Lesson(
      id: "u11-close", unit: 11,
      title: "Sextas",
      subtitle: "O intervalo que abre a mão",
      steps: [
        .reading(noteIDs: ["i-quality"]),
        .harmony(clef: .bass, range: 48...60, length: 6, voices: 2),
        .song(Songs.promenade),
        .technique(Technique.intervalStudy),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 12. Escala de Dó maior

  private static let unit12: [Lesson] = [
    Lesson(
      id: "u12-scale", unit: 12,
      title: "A escala de Dó maior",
      subtitle: "Oito notas e a passagem do polegar",
      steps: [
        .reading(noteIDs: ["s-major"]),
        .theory(count: 5),
        .play(clef: .treble, range: 60...72, length: 8),
        .play(clef: .bass, range: 48...60, length: 8),
      ]),
    Lesson(
      id: "u12-close", unit: 12,
      title: "Tônica, dominante, sensível",
      subtitle: "Os graus que dão direção à escala",
      steps: [
        .reading(noteIDs: ["s-degrees"]),
        .bothHands(rightRange: 60...72, leftRange: 48...60, length: 6),
        .technique(Technique.cScale),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 13. O acorde de Sol7

  private static let unit13: [Lesson] = [
    Lesson(
      id: "u13-seventh", unit: 13,
      title: "O acorde de Sol7",
      subtitle: "O acorde que pede resolução",
      steps: [
        .reading(noteIDs: ["c-what"]),
        .theory(count: 5),
        .harmony(clef: .treble, range: 59...67, length: 6, voices: 3),
        .harmony(clef: .bass, range: 47...60, length: 5, voices: 3),
      ]),
    Lesson(
      id: "u13-close", unit: 13,
      title: "Substituição de dedo",
      subtitle: "Trocar de dedo sem soltar a tecla",
      steps: [
        .song(Songs.trumpetVoluntary),
        .technique(Technique.chordWarmup),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 14. Acordes primários em Dó

  private static let unit14: [Lesson] = [
    Lesson(
      id: "u14-primary", unit: 14,
      title: "I, IV e V7",
      subtitle: "Os três acordes que harmonizam quase tudo",
      steps: [
        .reading(noteIDs: ["c-building"]),
        .theory(count: 5),
        .harmony(clef: .bass, range: 47...60, length: 6, voices: 3),
      ]),
    Lesson(
      id: "u14-inversion", unit: 14,
      title: "Inversão",
      subtitle: "O mesmo acorde, outro baixo",
      steps: [
        .reading(noteIDs: ["c-major-minor"]),
        .theory(count: 5),
        .harmony(clef: .treble, range: 60...72, length: 6, voices: 3),
      ]),
    Lesson(
      id: "u14-close", unit: 14,
      title: "Ler uma cifra",
      subtitle: "A melodia escrita, a harmonia nomeada",
      steps: [
        .song(Songs.homeOnTheRange),
        .technique(Technique.chordEtude),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 15. Escala de Sol maior

  private static let unit15: [Lesson] = [
    Lesson(
      id: "u15-key-signature", unit: 15,
      title: "Armadura de clave",
      subtitle: "O sustenido escrito uma vez, valendo sempre",
      steps: [
        .reading(noteIDs: ["s-key-signature"]),
        .theory(count: 5),
        .chromatic(clef: .treble, range: 67...79, length: 8),
        .chromatic(clef: .bass, range: 48...60, length: 6),
      ]),
    Lesson(
      id: "u15-close", unit: 15,
      title: "Minueto em Sol",
      subtitle: "A primeira peça com armadura",
      steps: [
        .song(Songs.minuetInG),
        .technique(Technique.gScaleDivided),
        .theory(count: 5),
      ]),
  ]

  // MARK: - Unit 16. Acordes primários em Sol

  private static let unit16: [Lesson] = [
    Lesson(
      id: "u16-d-seventh", unit: 16,
      title: "O acorde de Ré7",
      subtitle: "A dominante de Sol",
      steps: [
        .harmony(clef: .treble, range: 62...74, length: 6, voices: 3),
        .song(Songs.amazingGrace),
      ]),
    Lesson(
      id: "u16-lead-sheet", unit: 16,
      title: "Cifra em Sol",
      subtitle: "Construir a harmonia a partir do nome",
      steps: [
        .bothHands(rightRange: 67...79, leftRange: 48...60, length: 8),
        .song(Songs.jollyGoodFellow),
      ]),
    Lesson(
      id: "u16-close", unit: 16,
      title: "O Carnaval de Veneza",
      subtitle: "A peça de revisão: tudo que o curso construiu",
      steps: [
        .song(Songs.carnivalOfVenice),
        .technique(Technique.musicBoxEtude),
        .theory(count: 6),
      ]),
  ]
}
