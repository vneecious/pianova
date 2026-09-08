import ScoreModel

/// The ordered course.
///
/// The spine is the four-block syllabus of Med's *Introdução à Teoria da
/// Música* — **A** notação, **B** intervalos, **C** escalas, **D** acordes —
/// and every block is worked at the instrument, not only on paper. A block
/// opens with what the thing *is*, then reads it on the staff, then plays it,
/// and closes on a piece that uses it.
///
/// Two honest boundaries:
///
/// - The four blocks and their order come from the book. The lessons inside
///   each block are written here, from standard theory, not lifted from it.
/// - Note values, rests and time signatures are taught as **theory** only. The
///   engine checks which key was played, never when, so rhythm cannot yet be
///   graded at the instrument.
public enum Course {
  /// The lessons, first to last.
  public static let lessons: [Lesson] = blockA + blockB + blockC + blockD

  /// Lessons of one block, in order.
  /// - Parameter block: The block to list.
  /// - Returns: Its lessons.
  public static func lessons(in block: TheoryTopic) -> [Lesson] {
    lessons.filter { $0.block == block }
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

  // MARK: - A. Notação musical

  private static let blockA: [Lesson] = [
    Lesson(
      id: "a-staff", block: .notation,
      title: "A pauta",
      subtitle: "Cinco linhas e quatro espaços",
      steps: [
        .reading(noteIDs: ["n-staff"]),
        .theory(count: 4),
        .cards(clef: .treble, range: 60...62, count: 6),
        .cards(clef: .bass, range: 59...60, count: 6),
      ]),
    Lesson(
      id: "a-clefs", block: .notation,
      title: "As claves",
      subtitle: "Quem decide qual nota é qual",
      steps: [
        .reading(noteIDs: ["n-clefs"]),
        .theory(count: 5),
        .cards(clef: .bass, range: 59...60, count: 6),
      ]),
    Lesson(
      id: "a-middle-c", block: .notation,
      title: "O Dó central",
      subtitle: "A mesma tecla, nas duas claves",
      steps: [
        .reading(noteIDs: ["n-middle-c"]),
        .theory(count: 5),
        .cards(clef: .treble, range: 60...64, count: 8),
        .cards(clef: .bass, range: 57...60, count: 8),
        .play(clef: .treble, range: 60...64, length: 6),
      ]),
    Lesson(
      id: "a-note-values", block: .notation,
      title: "Figuras e valores",
      subtitle: "Semibreve, mínima, semínima, colcheia",
      steps: [
        .reading(noteIDs: ["n-values"]),
        .theory(count: 6),
        .play(clef: .bass, range: 57...60, length: 6),
      ]),
    Lesson(
      id: "a-five-fingers", block: .notation,
      title: "Cinco dedos",
      subtitle: "Dó a Sol na direita, Fá a Dó na esquerda",
      steps: [
        .cards(clef: .treble, range: 60...67, count: 10),
        .cards(clef: .bass, range: 53...60, count: 10),
        .play(clef: .treble, range: 60...67, length: 8),
        .song(Songs.frereJacques),
      ]),
    Lesson(
      id: "a-rhythm-quarters", block: .notation,
      title: "Tocar no tempo",
      subtitle: "Semínimas, uma por pulso",
      steps: [
        .rhythm(
          clef: .treble,
          pattern: [
            RhythmStepNote(Pitch(60), .quarter), RhythmStepNote(Pitch(62), .quarter),
            RhythmStepNote(Pitch(64), .quarter), RhythmStepNote(Pitch(62), .quarter),
            RhythmStepNote(Pitch(60), .quarter), RhythmStepNote(Pitch(62), .quarter),
            RhythmStepNote(Pitch(64), .quarter), RhythmStepNote(Pitch(60), .quarter),
          ],
          tempo: 60, beatsPerBar: 4)
      ]),
    Lesson(
      id: "a-rests", block: .notation,
      title: "Pausas",
      subtitle: "O silêncio também tem duração",
      steps: [
        .reading(noteIDs: ["n-rests"]),
        .theory(count: 5),
        .play(clef: .treble, range: 60...64, length: 8),
        .play(clef: .bass, range: 53...60, length: 8),
      ]),
    Lesson(
      id: "a-dot-tie", block: .notation,
      title: "Ponto e ligadura",
      subtitle: "Como se escreve uma duração maior",
      steps: [
        .reading(noteIDs: ["n-dot-tie"]),
        .theory(count: 5),
        .song(Songs.auClairDeLaLune),
      ]),
    Lesson(
      id: "a-bars", block: .notation,
      title: "Compasso",
      subtitle: "Linhas divisórias e unidade de tempo",
      steps: [
        .reading(noteIDs: ["n-bars"]),
        .theory(count: 6),
        .cards(clef: .bass, range: 48...60, count: 10),
        .song(Songs.auClairDeLaLuneBass),
      ]),
    Lesson(
      id: "a-rhythm-mixed", block: .notation,
      title: "Misturando figuras",
      subtitle: "Semibreve, mínima e semínima no mesmo trecho",
      steps: [
        .rhythm(
          clef: .treble,
          pattern: [
            RhythmStepNote(Pitch(60), .half), RhythmStepNote(Pitch(64), .half),
            RhythmStepNote(Pitch(62), .quarter), RhythmStepNote(Pitch(64), .quarter),
            RhythmStepNote(Pitch(65), .half),
            RhythmStepNote(Pitch(60), .whole),
          ],
          tempo: 60, beatsPerBar: 4),
        .rhythm(
          clef: .bass,
          pattern: [
            RhythmStepNote(Pitch(53), .half, dotted: true),
            RhythmStepNote(Pitch(55), .quarter),
            RhythmStepNote(Pitch(57), .half),
            RhythmStepNote(Pitch(60), .half),
          ],
          tempo: 60, beatsPerBar: 4),
      ]),
    Lesson(
      id: "a-ear-first", block: .notation,
      title: "Ouvir a nota",
      subtitle: "Reconhecer o som, sem nada escrito",
      steps: [
        .ear(clef: .treble, range: 60...64, count: 8),
        .play(clef: .treble, range: 60...64, length: 8),
      ]),
    Lesson(
      id: "a-treble-staff", block: .notation,
      title: "Dentro da pauta de sol",
      subtitle: "As cinco linhas da clave de sol",
      steps: [
        .cards(clef: .treble, range: 64...77, count: 12),
        .play(clef: .treble, range: 64...77, length: 8),
        .song(Songs.maryHadALittleLamb),
      ]),
    Lesson(
      id: "a-bass-staff", block: .notation,
      title: "Dentro da pauta de fá",
      subtitle: "As cinco linhas da clave de fá",
      steps: [
        .cards(clef: .bass, range: 43...57, count: 12),
        .play(clef: .bass, range: 43...57, length: 8),
      ]),
    Lesson(
      id: "a-ledger", block: .notation,
      title: "Linhas suplementares",
      subtitle: "Escrever fora da pauta, nos dois lados",
      steps: [
        .reading(noteIDs: ["n-ledger"]),
        .theory(count: 5),
        .cards(clef: .treble, range: 60...81, count: 10),
        .cards(clef: .bass, range: 41...60, count: 10),
      ]),
  ]

  // MARK: - B. Intervalos

  private static let blockB: [Lesson] = [
    Lesson(
      id: "b-what", block: .intervals,
      title: "O que é intervalo",
      subtitle: "A distância entre duas notas",
      steps: [
        .reading(noteIDs: ["i-what"]),
        .theory(count: 5),
        .play(clef: .treble, range: 60...72, length: 8),
        .play(clef: .bass, range: 48...60, length: 8),
      ]),
    Lesson(
      id: "b-melodic-harmonic", block: .intervals,
      title: "Melódico e harmônico",
      subtitle: "Um depois do outro, ou os dois juntos",
      steps: [
        .reading(noteIDs: ["i-melodic-harmonic"]),
        .theory(count: 5),
        .play(clef: .treble, range: 60...72, length: 8),
        .harmony(clef: .bass, range: 43...60, length: 6, voices: 2),
      ]),
    Lesson(
      id: "b-seconds-thirds", block: .intervals,
      title: "Segundas e terças",
      subtitle: "Vizinhas e saltos de uma",
      steps: [
        .reading(noteIDs: ["i-quality"]),
        .theory(count: 5),
        .harmony(clef: .treble, range: 60...77, length: 8, voices: 2),
        .harmony(clef: .bass, range: 43...60, length: 6, voices: 2),
      ]),
    Lesson(
      id: "b-fourths-fifths", block: .intervals,
      title: "Quartas e quintas",
      subtitle: "Os saltos que sustentam a harmonia",
      steps: [
        .theory(count: 5),
        .cards(clef: .bass, range: 43...57, count: 8),
        .play(clef: .treble, range: 60...69, length: 9),
        .song(Songs.twinkle),
      ]),
    Lesson(
      id: "b-both-clefs", block: .intervals,
      title: "Intervalos nas duas claves",
      subtitle: "O mesmo salto, lido dos dois lados",
      steps: [
        .harmony(clef: .bass, range: 43...60, length: 8, voices: 2),
        .cards(clef: .treble, range: 64...77, count: 8),
        .cards(clef: .bass, range: 43...57, count: 8),
      ]),
    Lesson(
      id: "b-ear-steps", block: .intervals,
      title: "Ouvir a distância",
      subtitle: "Reconhecer de ouvido dentro da posição de cinco dedos",
      steps: [
        .ear(clef: .treble, range: 60...67, count: 10),
        .ear(clef: .bass, range: 53...60, count: 8),
      ]),
    Lesson(
      id: "b-tone-semitone", block: .intervals,
      title: "Tom e semitom",
      subtitle: "A menor distância do teclado",
      steps: [
        .reading(noteIDs: ["i-tone-semitone"]),
        .theory(count: 5),
        .chromatic(clef: .treble, range: 60...72, length: 10),
        .chromatic(clef: .bass, range: 48...60, length: 10),
      ]),
  ]

  // MARK: - C. Escalas

  private static let blockC: [Lesson] = [
    Lesson(
      id: "c-what", block: .scales,
      title: "O que é escala",
      subtitle: "Notas em ordem de altura",
      steps: [
        .reading(noteIDs: ["s-what"]),
        .theory(count: 5),
        .play(clef: .treble, range: 60...72, length: 10),
      ]),
    Lesson(
      id: "c-major", block: .scales,
      title: "A escala maior",
      subtitle: "Onde caem os semitons",
      steps: [
        .reading(noteIDs: ["s-major"]),
        .theory(count: 5),
        .play(clef: .bass, range: 48...60, length: 10),
      ]),
    Lesson(
      id: "c-degrees", block: .scales,
      title: "Graus da escala",
      subtitle: "Tônica, dominante e o resto",
      steps: [
        .reading(noteIDs: ["s-degrees"]),
        .theory(count: 5),
        .play(clef: .treble, range: 60...72, length: 10),
        .song(Songs.jingleBells),
      ]),
    Lesson(
      id: "c-accidentals", block: .scales,
      title: "Sustenido, bemol, bequadro",
      subtitle: "As alterações e as teclas pretas",
      steps: [
        .reading(noteIDs: ["s-accidentals"]),
        .theory(count: 5),
        .chromatic(clef: .treble, range: 60...72, length: 12),
      ]),
    Lesson(
      id: "c-key-signature", block: .scales,
      title: "Armadura de clave",
      subtitle: "As alterações escritas uma vez só",
      steps: [
        .reading(noteIDs: ["s-key-signature"]),
        .theory(count: 5),
        .chromatic(clef: .bass, range: 48...60, length: 10),
      ]),
    Lesson(
      id: "c-wide", block: .scales,
      title: "Leitura ampla",
      subtitle: "Toda a extensão aprendida",
      steps: [
        .cards(clef: .treble, range: 60...84, count: 12),
        .cards(clef: .bass, range: 36...60, count: 12),
        .play(clef: .treble, range: 60...84, length: 12),
        .play(clef: .bass, range: 36...60, length: 12),
      ]),
  ]

  // MARK: - D. Acordes

  private static let blockD: [Lesson] = [
    Lesson(
      id: "d-what", block: .chords,
      title: "O que é acorde",
      subtitle: "Três sons ao mesmo tempo",
      steps: [
        .reading(noteIDs: ["c-what"]),
        .theory(count: 5),
        .harmony(clef: .treble, range: 60...77, length: 8, voices: 3),
      ]),
    Lesson(
      id: "d-building", block: .chords,
      title: "Como se monta uma tríade",
      subtitle: "Terças empilhadas",
      steps: [
        .reading(noteIDs: ["c-building"]),
        .theory(count: 5),
        .harmony(clef: .treble, range: 60...72, length: 8, voices: 3),
      ]),
    Lesson(
      id: "d-triads", block: .chords,
      title: "Tríades maiores e menores",
      subtitle: "O que muda é a terça",
      steps: [
        .reading(noteIDs: ["c-major-minor"]),
        .theory(count: 5),
        .harmony(clef: .bass, range: 43...60, length: 8, voices: 3),
      ]),
    Lesson(
      id: "d-arpeggio", block: .chords,
      title: "Arpejo",
      subtitle: "O mesmo acorde, uma nota de cada vez",
      steps: [
        .reading(noteIDs: ["c-arpeggio"]),
        .theory(count: 5),
        .play(clef: .treble, range: 60...77, length: 10),
        .harmony(clef: .treble, range: 60...72, length: 6, voices: 3),
      ]),
    Lesson(
      id: "d-both-hands", block: .chords,
      title: "As duas mãos juntas",
      subtitle: "Grande pauta: ler os dois lados de uma vez",
      steps: [
        .bothHands(rightRange: 60...67, leftRange: 48...55, length: 8),
        .bothHands(rightRange: 60...72, leftRange: 43...55, length: 10),
      ]),
    Lesson(
      id: "d-two-handed-piece", block: .chords,
      title: "Uma peça a duas mãos",
      subtitle: "Melodia na direita, baixo na esquerda",
      steps: [
        .bothHands(rightRange: 60...64, leftRange: 43...48, length: 8),
        .song(Songs.auClairDeLaLuneTwoHands),
      ]),
    Lesson(
      id: "d-ode-to-joy", block: .chords,
      title: "Hino à Alegria",
      subtitle: "Beethoven, e o fim desta trilha",
      steps: [
        .theory(count: 6),
        .play(clef: .treble, range: 60...67, length: 10),
        .song(Songs.odeToJoy),
      ]),
  ]
}
