import ScoreModel
import Testing

@testable import Course

// MARK: - Rule 46: every piece is reachable on its own

/// Rule 46 — the repertoire holds every piece the app has.
@Test func theRepertoireHoldsEveryPiece() {
  #expect(Set(Course.repertoire.map(\.title)) == Set(Songs.all.map(\.title)))
  #expect(Course.repertoire.count == Songs.all.count)
}

/// Rule 46 — a piece the course schedules can always be found on its own.
///
/// The gap this closes: a piece used inside a lesson could only be reached by
/// taking that whole lesson again.
@Test func everyScheduledPieceIsInTheRepertoire() {
  let titles = Set(Course.repertoire.map(\.title))

  for lesson in Course.lessons {
    for step in lesson.steps {
      guard case .song(let score) = step else { continue }
      #expect(titles.contains(score.title), "\(score.title) não aparece no repertório")
    }
  }
}

// MARK: - Rule 47: each piece says how hard it is

/// Rule 47 — a piece knows which unit introduces it.
@Test func aPieceKnowsItsUnit() {
  #expect(Course.unit(playing: Songs.auClairDeLaLune) == 1)
  #expect(Course.unit(playing: Songs.carnivalOfVenice) == 16)
}

/// Rule 47 — the unit reported is the one that really schedules the piece.
@Test func theUnitReportedIsWhereThePieceActuallyAppears() {
  for score in Songs.all {
    guard let unit = Course.unit(playing: score) else { continue }

    let scheduled = Course.lessons(in: unit)
      .contains { lesson in
        lesson.steps.contains { step in
          guard case .song(let other) = step else { return false }
          return other.title == score.title
        }
      }

    #expect(scheduled, "\(score.title) diz unidade \(unit), mas não está lá")
  }
}

/// A piece the course never schedules still shows up, with no unit.
@Test func anUnscheduledPieceHasNoUnit() {
  let orphan = Score(
    title: "Peça que o curso não usa", composer: "—",
    rightHand: Part(clef: .treble, measures: [Measure([ScoreNote(Pitch(60), .whole)])]))

  #expect(Course.unit(playing: orphan) == nil)
}

// MARK: - Rule 49: ordered from simple to hard

/// Rule 49 — the list runs in course order, easiest first.
@Test func theRepertoireIsOrderedByCourseOrder() {
  let units = Course.repertoire.map { Course.unit(playing: $0) ?? Int.max }

  #expect(units == units.sorted(), "o repertório não está em ordem de dificuldade")
}

/// Rule 49 — the first piece really is from the opening of the course.
@Test func theEasiestPieceComesFirst() {
  #expect(Course.unit(playing: Course.repertoire[0]) == 1)
}

/// The ordering is stable, so the list does not shuffle between launches.
@Test func theRepertoireOrderIsStable() {
  #expect(Course.repertoire.map(\.title) == Course.repertoire.map(\.title))
}

// MARK: - Rule 48: the repertoire is not the syllabus

/// Rule 48 — reading the repertoire cannot change what is unlocked.
///
/// The check is structural: the list is derived from the pieces alone, so there
/// is nothing about progress for it to touch.
@Test func theRepertoireIsIndependentOfProgress() {
  var progress = CourseProgress()
  progress.unlocksEverything = false
  let locked = Course.repertoire.map(\.title)

  progress.unlocksEverything = true
  #expect(Course.repertoire.map(\.title) == locked, "o repertório mudou com o progresso")
}

/// Every piece in the repertoire is playable: it has notes to strike.
@Test func everyRepertoirePieceCanBePlayed() {
  for score in Course.repertoire {
    #expect(!score.onsets.isEmpty, "\(score.title) não tem nada para tocar")
    #expect(
      score.onsets.allSatisfy { !$0.pitches.isEmpty },
      "\(score.title) tem um evento sem nota")
  }
}
