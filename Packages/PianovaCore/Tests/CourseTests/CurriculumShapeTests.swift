import ScoreModel
import Testing

@testable import Course

/// Clefs a lesson touches, whatever kind of step they come from.
///
/// A grand staff step touches both, which is the whole point of it.
private func clefs(of lesson: Lesson) -> Set<Clef> {
  Set(
    lesson.steps.flatMap { step -> [Clef] in
      switch step {
      case .theory, .reading: return []
      case .cards(let clef, _, _): return [clef]
      case .ear(let clef, _, _): return [clef]
      case .play(let clef, _, _): return [clef]
      case .harmony(let clef, _, _, _): return [clef]
      case .chromatic(let clef, _, _): return [clef]
      case .rhythm(let clef, _, _, _): return [clef]
      case .bothHands: return [.treble, .bass]
      case .song(let song): return song.isTwoHanded ? [.treble, .bass] : [song.clef]
      case .technique(let exercise):
        return exercise.isTwoHanded ? [.treble, .bass] : [exercise.clef]
      }
    })
}

/// Pitch ranges a lesson touches.
private func ranges(of lesson: Lesson) -> [ClosedRange<UInt8>] {
  lesson.steps.compactMap { step -> ClosedRange<UInt8>? in
    switch step {
    case .theory, .reading: return nil
    case .cards(_, let range, _): return range
    case .ear(_, let range, _): return range
    case .play(_, let range, _): return range
    case .harmony(_, let range, _, _): return range
    case .chromatic(_, let range, _): return range
    case .rhythm: return nil
    case .bothHands(let rightRange, _, _): return rightRange
    case .song, .technique: return nil
    }
  }
}

/// A two-handed step is read on both staves at once.
@Test func twoHandedStepsUseBothStaves() {
  let twoHanded = Course.lessons.flatMap(\.steps)
    .contains {
      guard case .bothHands = $0 else { return false }
      return true
    }

  #expect(twoHanded, "o curso deveria terminar com leitura a duas mãos")
}

/// A two-handed piece merges by onset, not note for note.
///
/// The old rule expected one bass note per melody note, which only held while
/// neither hand had rhythm. With real figures the left hand holds one note
/// under a whole bar, so what must be true is that the merge produces one
/// event per moment and loses nothing.
@Test func theTwoHandedPieceMergesByOnset() {
  let song = Songs.auClairDeLaLuneTwoHands
  let onsets = song.onsets

  #expect(song.isTwoHanded)
  #expect(onsets.count == Set(onsets.map(\.beats)).count, "dois eventos no mesmo instante")
  #expect(
    onsets.flatMap(\.pitches).count == song.melody.count + song.bass.count,
    "a fusão perdeu notas")

  // Where a hand starts a bar, both hands sound in the same event.
  #expect(onsets.first?.pitches.count == 2, "o primeiro tempo deveria ter as duas mãos")
}

/// Every piece the course can schedule fills its bars.
///
/// The check hand-written scores need most: it is arithmetic, it is invisible
/// by eye, and getting it wrong silently produces a score nobody can count.
@Test func everySongFillsItsBars() {
  for song in Songs.all {
    for bad in song.incompleteMeasures {
      Issue.record("\(song.title): compasso \(bad.index + 1) da \(bad.part) não fecha")
    }
  }
}

/// Every piece declares a real time signature and key.
@Test func everySongDeclaresItsTimeAndKey() {
  for song in Songs.all {
    #expect(song.timeSignature.beatsPerBar >= 2, "\(song.title) tem compasso estranho")
    #expect(abs(song.key.fifths) <= 7, "\(song.title) tem armadura impossível")
    #expect(!song.rightHand.measures.isEmpty, "\(song.title) não tem compasso nenhum")
  }
}

/// Hands sit on opposite sides of middle C in the two-handed piece.
@Test func theTwoHandedPieceSplitsAcrossTheStaves() {
  let song = Songs.auClairDeLaLuneTwoHands

  #expect(song.melody.allSatisfy { $0.grandStaffClef == .treble })
  #expect(song.bass.allSatisfy { $0.grandStaffClef == .bass })
}

/// A one-handed piece carries no left hand part.
@Test func oneHandedPiecesHaveNoLeftHandPart() {
  #expect(Songs.odeToJoy.isTwoHanded == false)
  #expect(Songs.odeToJoy.bass.isEmpty)
}

/// README › As duas claves — rule 15: the two clefs arrive together.
///
/// Teaching one clef to fluency before showing the other forces a relearn, so
/// the course never does it. The check is on the first lesson that reads a
/// staff at all: unit 1 is keyboard orientation and reads nothing.
@Test func bothClefsArriveTogether() {
  guard let first = Course.lessons.first(where: { !clefs(of: $0).isEmpty }) else {
    Issue.record("nenhuma lição lê pauta")
    return
  }

  #expect(clefs(of: first) == [.treble, .bass], "\(first.id) apresenta só uma clave")
}

/// Neither clef ever goes quiet for long.
///
/// A single lesson may lean one way — one built around note values naturally
/// does — but the rule is that no clef is left waiting while the other is
/// taught to fluency.
@Test func neitherClefGoesQuietForLong() {
  var gap: [Clef: Int] = [.treble: 0, .bass: 0]

  for lesson in Course.lessons {
    let used = clefs(of: lesson)

    for clef in [Clef.treble, .bass] {
      gap[clef] = used.contains(clef) ? 0 : (gap[clef] ?? 0) + 1
      #expect((gap[clef] ?? 0) <= 2, "\(clef) ficou de fora por 3 lições até \(lesson.id)")
    }
  }
}

/// Both clefs are in play by the end of the first unit that reads a staff.
@Test func bothClefsAppearInTheOpeningUnits() {
  let opening = Course.lessons.filter { $0.unit <= 2 }.flatMap { clefs(of: $0) }

  #expect(Set(opening) == [.treble, .bass])
}

/// The course grows outwards from middle C, so the first playing lesson sits
/// on it.
@Test func theCourseStartsAtMiddleC() {
  guard let first = Course.lessons.first(where: { !ranges(of: $0).isEmpty }) else {
    Issue.record("nenhuma lição toca nada")
    return
  }

  #expect(ranges(of: first).allSatisfy { $0.contains(60) }, "\(first.id) não parte do Dó central")
}

/// The course really does widen both clefs from start to finish.
///
/// Not every lesson widens: one built around a piece narrows on purpose, since
/// a beginner piece stays in a five-finger position. What must hold is that the
/// course ends up covering far more ground than it started with.
@Test func theCourseWidensBothClefs() {
  var first: [Clef: Int] = [:]
  var widest: [Clef: Int] = [:]

  for lesson in Course.lessons {
    for step in lesson.steps {
      let pair: (Clef, ClosedRange<UInt8>)? = {
        switch step {
        case .theory, .reading: return nil
        case .cards(let clef, let range, _): return (clef, range)
        case .ear(let clef, let range, _): return (clef, range)
        case .play(let clef, let range, _): return (clef, range)
        case .harmony(let clef, let range, _, _): return (clef, range)
        case .chromatic(let clef, let range, _): return (clef, range)
        case .rhythm: return nil
        case .bothHands(let rightRange, _, _): return (.treble, rightRange)
        case .song, .technique: return nil
        }
      }()
      guard let (clef, range) = pair else { continue }

      let span = Int(range.upperBound) - Int(range.lowerBound)
      if first[clef] == nil { first[clef] = span }
      widest[clef] = max(widest[clef] ?? 0, span)
    }
  }

  for clef in [Clef.treble, .bass] {
    #expect(first[clef] != nil, "\(clef) nunca aparece no curso")
    #expect((widest[clef] ?? 0) > (first[clef] ?? 0), "\(clef) não se expande ao longo do curso")
  }
}

/// A unit occupies one continuous stretch of the trail, never two.
@Test func eachUnitIsOneContinuousStretch() {
  var seen: [Int] = []

  for unit in Course.lessons.map(\.unit) where seen.last != unit {
    #expect(!seen.contains(unit), "a unidade \(unit) aparece em dois trechos")
    seen.append(unit)
  }

  #expect(seen == Array(1...16))
}

/// Theory is integrated, not bolted on: every unit both explains and plays.
@Test func everyUnitMixesTheoryWithTheInstrument() {
  for unit in CourseUnits.all {
    let lessons = Course.lessons(in: unit.number)

    #expect(lessons.contains { $0.hasTheory }, "unidade \(unit.number) não explica nada")
    #expect(
      lessons.contains { lesson in
        lesson.steps.contains { step in
          switch step {
          case .play, .harmony, .chromatic, .bothHands, .song, .rhythm, .technique:
            return true
          default:
            return false
          }
        }
      }, "unidade \(unit.number) não chega ao instrumento")
  }
}

/// Rhythm is not only explained: the course makes you play in time.
@Test func theCourseAsksYouToPlayInTime() {
  let hasRhythm = Course.lessons.flatMap(\.steps)
    .contains {
      guard case .rhythm = $0 else { return false }
      return true
    }

  #expect(hasRhythm, "o curso deveria cobrar ritmo, não só ensinar figuras")
}

/// A written rhythm fills whole bars.
///
/// A phrase that stops mid-bar reads as a mistake, and would teach the wrong
/// thing about how bars are counted.
@Test func rhythmPatternsFillWholeBars() {
  for lesson in Course.lessons {
    for step in lesson.steps {
      guard case .rhythm(_, let pattern, _, let beatsPerBar) = step else { continue }

      let beats = pattern.reduce(0.0) { $0 + Duration($1.value, dotted: $1.isDotted).beats }
      let remainder = beats.truncatingRemainder(dividingBy: Double(beatsPerBar))

      #expect(abs(remainder) < 0.001, "\(lesson.id) tem um compasso incompleto: \(beats) tempos")
    }
  }
}

/// A first rhythm is slow enough to be read, not raced.
@Test func rhythmLessonsStartAtAReadableTempo() {
  for lesson in Course.lessons {
    for step in lesson.steps {
      guard case .rhythm(_, _, let tempo, _) = step else { continue }
      #expect(tempo <= 90, "\(lesson.id) é rápido demais para uma primeira leitura")
    }
  }
}

/// Rhythm is only asked once note values have been taught.
@Test func rhythmComesAfterNoteValuesAreTaught() {
  var taughtValues = false

  for lesson in Course.lessons {
    if lesson.readingIDs.contains("n-values") { taughtValues = true }

    for step in lesson.steps {
      guard case .rhythm = step else { continue }
      #expect(taughtValues, "\(lesson.id) cobra ritmo antes de ensinar as figuras")
    }
  }
}

/// The course trains the ear, not only the eye.
@Test func theCourseTrainsTheEar() {
  let hasEar = Course.lessons.flatMap(\.steps)
    .contains {
      guard case .ear = $0 else { return false }
      return true
    }

  #expect(hasEar, "o curso deveria ter atividade auditiva")
}

/// Ear work stays inside a range the hand already knows.
///
/// Naming a sound is hard enough without also being asked to place it in a
/// register the player has never played.
@Test func earWorkStaysInsideAFamiliarRange() {
  for lesson in Course.lessons {
    for step in lesson.steps {
      guard case .ear(_, let range, _) = step else { continue }
      let span = Int(range.upperBound) - Int(range.lowerBound)
      #expect(span <= 12, "\(lesson.id) pede ouvido numa extensão larga demais")
    }
  }
}

/// Every note the course can ask has a key on the on-screen keyboard.
///
/// Same rule as the drill: without an instrument the screen is the only way to
/// answer, so a lesson reaching outside the keyboard would be unplayable.
@Test func everyCourseNoteExistsOnTheScreenKeyboard() {
  let keys = KeyboardLayout.standard.range

  for lesson in Course.lessons {
    for range in ranges(of: lesson) {
      #expect(
        keys.contains(range.lowerBound) && keys.contains(range.upperBound),
        "\(lesson.id) pede \(range), fora do teclado \(keys)")
    }
  }

  // Every piece and every drill the course actually schedules, rather than a
  // hand-kept list that goes stale the moment a piece is added.
  for lesson in Course.lessons {
    for step in lesson.steps {
      switch step {
      case .song(let song):
        for pitch in song.melody + song.bass {
          #expect(keys.contains(pitch.midiNoteNumber), "\(song.title) usa \(pitch.scientificName)")
        }
      case .technique(let exercise):
        for note in exercise.notes {
          #expect(
            keys.contains(note.pitch.midiNoteNumber),
            "\(exercise.id) usa \(note.pitch.scientificName)")
        }
      default:
        continue
      }
    }
  }
}
