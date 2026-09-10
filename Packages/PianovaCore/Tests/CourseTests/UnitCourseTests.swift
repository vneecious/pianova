import ScoreModel
import Testing

@testable import Course

/// Every pitch a lesson spells out note by note.
///
/// Only written content counts here. A step that hands a *range* to a generator
/// is not asking for a black key — the generators draw naturals, and the one
/// step that does not is `.chromatic`, which is checked on its own.
private func writtenPitches(in lesson: Lesson) -> [Pitch] {
  lesson.steps.flatMap { step -> [Pitch] in
    switch step {
    case .song(let song):
      return song.melody + song.bass
    case .technique(let exercise):
      return exercise.notes.map(\.pitch)
    case .rhythm(_, let pattern, _, _):
      return pattern.map(\.pitch)
    default:
      return []
    }
  }
}

/// Every written figure a lesson spells out.
private func writtenValues(in lesson: Lesson) -> [NoteValue] {
  lesson.steps.flatMap { step -> [NoteValue] in
    switch step {
    case .technique(let exercise):
      return exercise.notes.map(\.value)
    case .rhythm(_, let pattern, _, _):
      return pattern.map(\.value)
    default:
      return []
    }
  }
}

// MARK: - Rule 20: sixteen units, in order

/// Rule 20 — the course has exactly sixteen units.
@Test func theCourseHasSixteenUnits() {
  #expect(CourseUnits.all.count == 16)
}

/// Rule 20 — the units are numbered 1 to 16 with no gap and no repeat.
@Test func unitsAreNumberedInOrder() {
  #expect(CourseUnits.all.map(\.number) == Array(1...16))
}

/// Rule 20 — every lesson belongs to a real unit.
@Test func everyLessonBelongsToAUnit() {
  for lesson in Course.lessons {
    #expect(CourseUnits.unit(lesson.unit) != nil, "\(lesson.id) está fora das 16 unidades")
  }
}

/// Rule 20 — the trail never goes back: units appear in ascending order.
@Test func lessonsRunInUnitOrder() {
  let units = Course.lessons.map(\.unit)
  #expect(units == units.sorted(), "a trilha volta para uma unidade anterior")
}

/// Rule 20 — every unit actually has lessons.
@Test func everyUnitHasAtLeastOneLesson() {
  for unit in CourseUnits.all {
    let lessons = Course.lessons(in: unit.number)
    #expect(!lessons.isEmpty, "unidade \(unit.number) está vazia")
  }
}

// MARK: - Rule 21: each unit debuts something

/// Rule 21 — no two units claim the same debut concept.
@Test func eachUnitIntroducesItsOwnConcept() {
  let concepts = CourseUnits.all.map(\.concept)
  #expect(Set(concepts).count == concepts.count, "duas unidades estreiam o mesmo conceito")
}

/// Rule 21 — a unit that debuts nothing has no reason to exist.
@Test func everyUnitStatesWhatItIntroduces() {
  for unit in CourseUnits.all {
    #expect(!unit.concept.isEmpty, "unidade \(unit.number) não diz o que estreia")
    #expect(!unit.title.isEmpty, "unidade \(unit.number) não tem título")
  }
}

// MARK: - Rule 22: every unit closes on technique then theory

/// Rule 22 — the last lesson of every unit ends with technique, then theory.
@Test func everyUnitClosesOnTechniqueThenTheory() {
  for unit in CourseUnits.all {
    guard let last = Course.lessons(in: unit.number).last else {
      Issue.record("unidade \(unit.number) está vazia")
      continue
    }

    guard last.steps.count >= 2 else {
      Issue.record("unidade \(unit.number) fecha com menos de duas atividades")
      continue
    }

    let closing = last.steps.suffix(2)
    guard case .technique = closing.first else {
      Issue.record("unidade \(unit.number) não fecha com técnica guiada")
      continue
    }
    guard case .theory = closing.last else {
      Issue.record("unidade \(unit.number) não fecha com teoria")
      continue
    }
  }
}

// MARK: - Rule 23: nothing is asked before it is taught

/// Rule 23 — no black key is written before unit 10, where accidentals debut.
@Test func noAccidentalBeforeSharpsAreTaught() {
  for lesson in Course.lessons where lesson.unit < 10 {
    for pitch in writtenPitches(in: lesson) where pitch.requiresSharp {
      Issue.record("\(lesson.id) pede \(pitch.scientificName) antes da unidade 10")
    }
  }
}

/// Rule 23 — and no step that *generates* black keys either.
@Test func noChromaticStepBeforeSharpsAreTaught() {
  for lesson in Course.lessons where lesson.unit < 10 {
    for step in lesson.steps {
      guard case .chromatic = step else { continue }
      Issue.record("\(lesson.id) gera acidentes antes da unidade 10")
    }
  }
}

/// Rule 23 — no eighth note before unit 6, where they debut.
@Test func noEighthNoteBeforeTheyAreTaught() {
  for lesson in Course.lessons where lesson.unit < 6 {
    #expect(
      !writtenValues(in: lesson).contains(.eighth),
      "\(lesson.id) escreve colcheia antes da unidade 6")
  }
}

/// Rule 23 — a lesson only reads pages the course has already reached.
@Test func questionsOnlyComeFromPagesAlreadyRead() {
  for lesson in Course.lessons {
    let taught = Course.pagesTaught(upTo: lesson)
    for question in Course.eligibleQuestions(for: lesson) {
      #expect(taught.contains(question.noteID), "\(lesson.id) pergunta sobre página não lida")
    }
  }
}

/// Rule 23 — every teaching page a lesson names actually exists.
@Test func everyReadingPageExists() {
  for lesson in Course.lessons {
    for id in lesson.readingIDs {
      #expect(TheoryNotes.note(id) != nil, "\(lesson.id) lê página inexistente: \(id)")
    }
  }
}

// MARK: - Rules 24-27: the exercises are guided

/// All technique exercises in the course.
private var allExercises: [TechniqueExercise] {
  Course.lessons.flatMap(\.techniqueExercises)
}

/// Rule 22 — sixteen units means sixteen closing drills, at least.
@Test func thereIsATechniqueExercisePerUnit() {
  let units = Set(
    Course.lessons.filter { !$0.techniqueExercises.isEmpty }.map(\.unit))
  #expect(
    units == Set(1...16), "faltam exercícios de técnica em: \(Set(1...16).subtracting(units))")
}

/// Rule 24 — an exercise with no goal and no instructions is not guided.
@Test func everyExerciseIsGuided() {
  for exercise in allExercises {
    #expect(!exercise.goal.isEmpty, "\(exercise.id) não diz o objetivo")
    #expect(!exercise.hints.isEmpty, "\(exercise.id) não tem instruções de execução")
    for hint in exercise.hints {
      #expect(!hint.isEmpty, "\(exercise.id) tem instrução vazia")
    }
  }
}

/// Rule 25 — every note declares a real finger.
@Test func everyExerciseNoteHasAFinger() {
  for exercise in allExercises {
    for note in exercise.notes {
      #expect(
        (1...5).contains(note.finger),
        "\(exercise.id): dedo \(note.finger) em \(note.pitch.scientificName)")
    }
  }
}

/// Rule 26 — the exercise can be tapped before it is played, so it must carry a
/// rhythm note for note.
@Test func everyExerciseCanBeTappedBeforePlayed() {
  for exercise in allExercises {
    #expect(
      exercise.rhythmPattern.count == exercise.notes.count,
      "\(exercise.id) não produz um ritmo completo")
  }
}

/// Rule 27 — an exercise is played in time, so it needs a workable tempo and bar.
@Test func everyExerciseHasAPlayableTempo() {
  for exercise in allExercises {
    #expect(
      (40...132).contains(exercise.tempo),
      "\(exercise.id): andamento \(exercise.tempo) fora do razoável")
    #expect(exercise.beatsPerBar >= 2, "\(exercise.id): compasso de \(exercise.beatsPerBar)")
    #expect(!exercise.notes.isEmpty, "\(exercise.id) não tem notas")
  }
}

/// An exercise fills whole bars: a drill that stops mid-bar cannot be counted.
@Test func everyExerciseFillsWholeBars() {
  for exercise in allExercises {
    let beats = exercise.notes.reduce(0.0) { $0 + $1.duration.beats }
    let perBar = Double(exercise.beatsPerBar)
    #expect(
      beats.truncatingRemainder(dividingBy: perBar) == 0,
      "\(exercise.id): \(beats) tempos não fecham compassos de \(perBar)")
  }
}

/// Exercise identifiers are unique.
@Test func exerciseIdentifiersAreUnique() {
  let ids = allExercises.map(\.id)
  #expect(Set(ids).count == ids.count)
}

/// A hand plays with fingers, not with an octave leap between consecutive
/// fingers: a five-finger drill must stay inside a hand span.
@Test func exerciseNotesStayWithinAHandSpan() {
  for exercise in allExercises {
    for hand in exercise.hands {
      let played = exercise.notes.filter { $0.hand == hand }.map { Int($0.pitch.midiNoteNumber) }
      guard let low = played.min(), let high = played.max() else { continue }
      #expect(
        high - low <= 24,
        "\(exercise.id): \(hand.name) percorre \(high - low) semitons de uma vez")
    }
  }
}
