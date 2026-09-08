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
    case .song: return nil
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

/// The two-handed piece pairs every melody note with a left hand note.
@Test func theTwoHandedPieceIsFullyPaired() {
  let song = Songs.auClairDeLaLuneTwoHands

  #expect(song.isTwoHanded)
  #expect(song.leftHandNotes.count == song.notes.count)
}

/// Hands sit on opposite sides of middle C in the two-handed piece.
@Test func theTwoHandedPieceSplitsAcrossTheStaves() {
  let song = Songs.auClairDeLaLuneTwoHands

  #expect(song.notes.allSatisfy { $0.grandStaffClef == .treble })
  #expect(song.leftHandNotes.allSatisfy { $0.grandStaffClef == .bass })
}

/// A one-handed piece carries no left hand part.
@Test func oneHandedPiecesHaveNoLeftHandPart() {
  #expect(Songs.odeToJoy.isTwoHanded == false)
  #expect(Songs.odeToJoy.leftHandNotes.isEmpty)
}

/// README › As duas claves — rule 15: bass clef is there from lesson one.
///
/// Teaching one clef to fluency before showing the other forces a relearn, so
/// the course never does it.
@Test func bothClefsAppearInTheFirstLesson() {
  #expect(clefs(of: Course.lessons[0]) == [.treble, .bass])
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

/// Both clefs are in play from the very start of the course.
@Test func bothClefsAppearInTheOpeningLessons() {
  let opening = Course.lessons.prefix(3).flatMap { clefs(of: $0) }

  #expect(Set(opening) == [.treble, .bass])
}

/// No lesson introduces a clef the course has not shown before it.
@Test func noClefIsIntroducedLate() {
  var seen: Set<Clef> = []

  for lesson in Course.lessons {
    seen.formUnion(clefs(of: lesson))
    if lesson.id == Course.lessons[0].id {
      #expect(seen == [.treble, .bass])
    }
  }

  #expect(seen == [.treble, .bass])
}

/// The course grows outwards from middle C, so the first lesson sits on it.
@Test func theCourseStartsAtMiddleC() {
  let first = ranges(of: Course.lessons[0])

  #expect(first.allSatisfy { $0.contains(60) })
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
        case .song: return nil
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

/// The course is organised in the four blocks of the syllabus, in order, with
/// no block interleaved into another.
@Test func lessonsAreGroupedByBlockInSyllabusOrder() {
  let blocks = Course.lessons.map(\.block)
  var seen: [TheoryTopic] = []

  for block in blocks where seen.last != block {
    #expect(!seen.contains(block), "o bloco \(block.rawValue) aparece em dois trechos")
    seen.append(block)
  }

  #expect(seen == TheoryTopic.allCases)
}

/// Every block has lessons.
@Test func everyBlockHasLessons() {
  for block in TheoryTopic.allCases {
    #expect(!Course.lessons(in: block).isEmpty, "bloco \(block.rawValue) vazio")
  }
}

/// Theory is integrated, not bolted on: every block has at least one lesson
/// that both explains and plays.
@Test func everyBlockMixesTheoryWithTheInstrument() {
  for block in TheoryTopic.allCases {
    let lessons = Course.lessons(in: block)

    #expect(lessons.contains { $0.hasTheory }, "bloco \(block.rawValue) não explica nada")
    #expect(
      lessons.contains { lesson in
        lesson.steps.contains { step in
          switch step {
          case .play, .harmony, .chromatic, .bothHands, .song, .rhythm: return true
          default: return false
          }
        }
      }, "bloco \(block.rawValue) não chega ao instrumento")
  }
}

/// A lesson's own teaching pages belong to its own block.
///
/// The old rule checked the block on the step itself. That was too weak: it
/// let a lesson on clefs ask about note values, because both are block A.
/// Gating is now per page — see `noQuestionIsAskedBeforeItsPageIsTaught`.
@Test func lessonsTeachOnlyTheirOwnBlock() {
  for lesson in Course.lessons {
    for id in lesson.readingIDs {
      #expect(TheoryNotes.note(id)?.topic == lesson.block, "\(lesson.id) ensina outro bloco")
    }
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
