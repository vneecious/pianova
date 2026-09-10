import Testing

@testable import Course

/// Every block has questions, so no lesson can ask for an empty round.
@Test func everyBlockHasQuestions() {
  for topic in TheoryTopic.allCases {
    #expect(TheoryBank.questions(for: topic).count >= 8, "\(topic.rawValue) tem poucas questões")
  }
}

/// Identifiers are unique across the whole bank.
@Test func theoryIdentifiersAreUnique() {
  #expect(Set(TheoryBank.all.map(\.id)).count == TheoryBank.all.count)
}

/// A question filed under a block really belongs to it.
@Test func questionsAreFiledUnderTheirOwnBlock() {
  for topic in TheoryTopic.allCases {
    #expect(TheoryBank.questions(for: topic).allSatisfy { $0.topic == topic })
  }
}

/// Every question offers a real choice and points at a valid answer.
@Test func everyQuestionHasAValidAnswer() {
  for question in TheoryBank.all {
    #expect(question.options.count >= 2, "\(question.id) não oferece escolha")
    #expect(question.options.indices.contains(question.correctIndex), "\(question.id) aponta fora")
    #expect(!question.explanation.isEmpty, "\(question.id) não explica o porquê")
  }
}

/// No question repeats an option, which would make two answers right.
@Test func optionsAreDistinct() {
  for question in TheoryBank.all {
    #expect(Set(question.options).count == question.options.count, "\(question.id) repete opção")
  }
}

/// The blocks are ordered as the syllabus has them.
@Test func blocksAreOrderedAsTheSyllabus() {
  #expect(TheoryTopic.allCases.map(\.letter) == ["A", "B", "C", "D"])
  #expect(TheoryTopic.allCases.map(\.rawValue) == ["notation", "intervals", "scales", "chords"])
}

/// A right answer moves on to the next question.
@Test func aRightTheoryAnswerAdvances() {
  let questions = Array(TheoryBank.questions(for: .notation).prefix(2))
  var session = TheorySession(questions: questions)

  let outcome = session.answer(questions[0].correctIndex)

  #expect(outcome == .correct)
  #expect(session.currentQuestion == questions[1])
  #expect(session.correctCount == 1)
}

/// A wrong answer reveals the right one and sends the question to the back.
@Test func aWrongTheoryAnswerIsPostponed() {
  let questions = Array(TheoryBank.questions(for: .notation).prefix(2))
  var session = TheorySession(questions: questions)
  let wrongIndex = (questions[0].correctIndex + 1) % questions[0].options.count

  let outcome = session.answer(wrongIndex)

  #expect(outcome == .wrong(expected: questions[0].correctOption))
  #expect(session.queue.last == questions[0])
  #expect(session.mistakeCount == 1)
}

/// A missed question must still be answered before the round can end.
@Test func aMissedTheoryQuestionKeepsTheRoundOpen() {
  let questions = Array(TheoryBank.questions(for: .intervals).prefix(1))
  var session = TheorySession(questions: questions)
  let wrongIndex = (questions[0].correctIndex + 1) % questions[0].options.count

  _ = session.answer(wrongIndex)
  #expect(session.isFinished == false)

  let outcome = session.answer(questions[0].correctIndex)
  #expect(outcome == .finished)
  #expect(session.isFinished)
}

/// Answering an empty round is harmless.
@Test func answeringAnEmptyTheoryRoundIsHarmless() {
  var session = TheorySession(questions: [])

  #expect(session.answer(0) == .finished)
  #expect(session.correctCount == 0)
}

/// Every block explains itself, not only tests itself.
@Test func everyBlockHasTeachingPages() {
  for topic in TheoryTopic.allCases {
    let pages = TheoryNotes.all.filter { $0.topic == topic }
    #expect(pages.count >= 4, "\(topic.rawValue) tem poucas páginas de teoria")
  }
}

/// Page identifiers are unique, since the lessons reference them by name.
@Test func teachingPageIdentifiersAreUnique() {
  #expect(Set(TheoryNotes.all.map(\.id)).count == TheoryNotes.all.count)
}

/// Every page actually says something.
///
/// Measured over the page, not paragraph by paragraph: a short, blunt sentence
/// in the middle of an explanation is good writing, not a thin one.
@Test func everyTeachingPageHasContent() {
  for note in TheoryNotes.all {
    #expect(!note.title.isEmpty, "\(note.id) sem título")
    #expect(note.body.count >= 2, "\(note.id) explica pouco")
    #expect(note.body.allSatisfy { !$0.isEmpty }, "\(note.id) tem parágrafo vazio")

    let total = note.body.reduce(0) { $0 + $1.count }
    #expect(total >= 200, "\(note.id) é rasa demais para ensinar algo")
  }
}

/// Every page a lesson references really exists.
///
/// The lessons name pages by identifier, so a typo would silently show nothing.
@Test func everyReferencedPageExists() {
  for lesson in Course.lessons {
    for id in lesson.readingIDs {
      #expect(TheoryNotes.note(id) != nil, "\(lesson.id) aponta para a página inexistente \(id)")
    }
  }
}

/// No teaching page is read twice by two different lessons.
///
/// A page shown again as if it were new tells the player they forgot something
/// they were never taught twice. Review happens through the questions, which
/// keep drawing on every page already read.
@Test func noTeachingPageIsReadTwice() {
  let ids = Course.lessons.flatMap(\.readingIDs)

  #expect(Set(ids).count == ids.count, "há página ensinada em duas lições")
}

/// Explanation comes before examination: in any lesson that has both, the
/// reading is the earlier step.
@Test func readingComesBeforeQuestions() {
  for lesson in Course.lessons {
    guard
      let readingAt = lesson.steps.firstIndex(where: {
        guard case .reading = $0 else { return false }
        return true
      }),
      let theoryAt = lesson.steps.firstIndex(where: {
        guard case .theory = $0 else { return false }
        return true
      })
    else { continue }

    #expect(readingAt < theoryAt, "\(lesson.id) pergunta antes de explicar")
  }
}

/// Every teaching page is reachable from some lesson, so nothing written is
/// left stranded.
@Test func everyTeachingPageIsUsed() {
  let referenced = Set(Course.lessons.flatMap(\.readingIDs))

  for note in TheoryNotes.all {
    #expect(referenced.contains(note.id), "a página \(note.id) não é usada por nenhuma lição")
  }
}

/// Nothing is asked before it is taught.
///
/// This is the rule that matters most: reading about staves and clefs and then
/// being asked how long a minim lasts is not a quiz, it is a trap.
@Test func noQuestionIsAskedBeforeItsPageIsTaught() {
  var taught: Set<String> = []

  for lesson in Course.lessons {
    taught.formUnion(lesson.readingIDs)

    for step in lesson.steps {
      guard case .theory = step else { continue }

      for question in Course.eligibleQuestions(for: lesson) {
        #expect(
          taught.contains(question.noteID),
          "\(lesson.id) poderia perguntar \(question.id), de página não lida")
      }
    }
  }
}

/// A lesson prefers its own pages: the round is about what was just read.
@Test func aLessonAsksAboutWhatItJustTaught() {
  for lesson in Course.lessons where !lesson.readingIDs.isEmpty {
    guard
      lesson.steps.contains(where: {
        guard case .theory = $0 else { return false }
        return true
      })
    else { continue }

    let own = Set(lesson.readingIDs)
    let eligible = Course.eligibleQuestions(for: lesson)

    #expect(eligible.first.map { own.contains($0.noteID) } == true, "\(lesson.id) começa fora")
  }
}

/// A theory round always has enough questions to fill it.
@Test func everyTheoryRoundCanBeFilled() {
  for lesson in Course.lessons {
    for step in lesson.steps {
      guard case .theory(let count) = step else { continue }
      #expect(
        Course.eligibleQuestions(for: lesson).count >= count,
        "\(lesson.id) pede \(count) questões e não há tantas ensinadas")
    }
  }
}

/// Every question points at a page that exists.
@Test func everyQuestionPointsAtARealPage() {
  for question in TheoryBank.all {
    #expect(TheoryNotes.note(question.noteID) != nil, "\(question.id) aponta para página fantasma")
  }
}

/// A question belongs to the same block as the page that teaches it.
@Test func questionsMatchTheirPageBlock() {
  for question in TheoryBank.all {
    #expect(
      TheoryNotes.note(question.noteID)?.topic == question.topic, "\(question.id) desalinhado")
  }
}

/// A lesson teaches one concept.
///
/// Bundling two pages under one title means the round can ask about something
/// the title never promised — reading about rests and then being quizzed on
/// ties. Short lessons are also simply better received.
@Test func aLessonTeachesOneConceptAtATime() {
  for lesson in Course.lessons {
    #expect(
      lesson.readingIDs.count <= 1,
      "\(lesson.id) ensina \(lesson.readingIDs.count) conceitos de uma vez")
  }
}

/// A lesson that teaches something also asks about it.
@Test func aTaughtPageIsAlwaysExamined() {
  for lesson in Course.lessons where !lesson.readingIDs.isEmpty {
    let asks = lesson.steps.contains {
      guard case .theory = $0 else { return false }
      return true
    }

    #expect(asks, "\(lesson.id) ensina e não pergunta nada")
  }
}

/// Every teaching page has questions of its own, so a lesson can be examined
/// on what it just taught rather than only on revision.
@Test func everyPageHasItsOwnQuestions() {
  for note in TheoryNotes.all {
    let own = TheoryBank.all.filter { $0.noteID == note.id }
    #expect(own.count >= 2, "a página \(note.id) tem \(own.count) questão(ões)")
  }
}

/// Every question stands on its own.
///
/// The bank is shuffled, so a question written as a follow-up to the one before
/// it can appear with nothing before it. "E na clave de fá?" is not a question
/// when it arrives first.
@Test func questionsDoNotDependOnThePreviousOne() {
  for question in TheoryBank.all {
    #expect(
      !question.prompt.hasPrefix("E "),
      "\(question.id) começa como continuação: \"\(question.prompt)\"")
    #expect(
      question.prompt.hasSuffix("?") || question.prompt.hasSuffix(":"),
      "\(question.id) não é uma pergunta completa")
  }
}

/// No two questions ask the same thing in the same words.
///
/// Identical prompts on different pages would read as a bug to the player, and
/// as revision that teaches nothing.
@Test func questionsDoNotRepeatThemselves() {
  let prompts = TheoryBank.all.map { "\($0.prompt)|\($0.glyph)" }

  #expect(Set(prompts).count == prompts.count, "há perguntas com o mesmo enunciado")
}
