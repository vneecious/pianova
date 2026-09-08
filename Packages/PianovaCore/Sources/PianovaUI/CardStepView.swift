import NoteQuiz
import Progress
import ScoreModel
import Sound
import SwiftUI

/// A run of cards inside a lesson.
struct CardStepView: View {
  @StateObject private var controller: CardRoundController

  private let onFinished: () -> Void

  /// Steps a placement card may be answered with: every note the lesson covers.
  ///
  /// Drawn from the lesson's whole range, never from the card, so the choices
  /// give nothing away.
  private let targetSteps: [Int]

  @EnvironmentObject private var tones: TonePlayer
  private let profile: ProfileController

  init(
    clef: Clef,
    range: ClosedRange<UInt8>,
    count: Int,
    profile: ProfileController,
    direction: CardDirection? = nil,
    onFinished: @escaping () -> Void
  ) {
    let level = QuizLevel(sections: [.init(clef: clef, range: range)])
    let pool = CardDeck.pool(for: level)

    // Ask what the player has never met, then what they keep missing. This is
    // the difference between drilling and learning.
    var byKey: [ReviewKey: NoteCard] = [:]
    for card in pool {
      byKey[.note(midi: card.pitch.midiNoteNumber, clef: card.clef)] = card
    }
    let ordered = profile.prioritise(Array(byKey.keys)).compactMap { byKey[$0] }
    let chosen = Array(ordered.prefix(count))

    // A fixed direction means an ear round; otherwise the usual mix of naming
    // and placement.
    let cards =
      direction.map { asked in chosen.map { $0.asking(asked) } }
      ?? CardDeck.markingReversed(chosen)

    self.profile = profile

    targetSteps = Set(CardDeck.naturalPitches(in: range).map { $0.staffStep(in: clef) })
      .sorted()

    _controller = StateObject(wrappedValue: CardRoundController(cards: cards))
    self.onFinished = onFinished
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      if let card = displayedCard {
        prompt(for: card)
        staff(for: card)
      }

      feedbackLine
      answerButtons
    }
    .onAppear {
      controller.onFinished = onFinished
      controller.onAnswered = { card, wasCorrect in
        profile.recordNote(card.pitch, clef: card.clef, wasCorrect: wasCorrect)
      }
    }
  }

  /// While revealing, the missed card stays on screen instead of the next one.
  private var displayedCard: NoteCard? {
    controller.reveal?.card ?? controller.session.currentCard
  }

  @ViewBuilder
  private func prompt(for card: NoteCard) -> some View {
    HStack(alignment: .firstTextBaseline) {
      switch card.direction {
      case .nameTheNote:
        Text("Que nota é esta?")
          .font(.system(size: 22, weight: .semibold))
      case .placeTheNote:
        Text("Onde fica o \(card.pitch.solfegeWithOctave)?")
          .font(.system(size: 22, weight: .semibold))
      case .hearTheNote:
        Text("Que nota você ouviu?")
          .font(.system(size: 22, weight: .semibold))
      }

      Spacer()

      Text("\(controller.remainingCount) restantes")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
  }

  @ViewBuilder
  private func staff(for card: NoteCard) -> some View {
    switch card.direction {
    case .hearTheNote:
      listenPanel(card)

    case .nameTheNote:
      StaffView(
        clef: card.clef,
        noteGroups: [[card.pitch]],
        states: [controller.reveal == nil ? .current : .done],
        staffSpace: 20
      )
      .padding(.horizontal, 8)

    case .placeTheNote:
      VStack(alignment: .leading, spacing: 4) {
        Text("Toque no marcador da posição certa. O número é a oitava — Dó 4 é o dó central.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)

        StaffView(
          clef: card.clef,
          noteGroups: [],
          states: [],
          marks: placementMarks,
          showsLedgerGuides: true,
          tapTargets: controller.reveal == nil ? targetSteps : [],
          staffSpace: 20,
          onTapStep: { controller.answer(.staffStep($0)) }
        )
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  /// Nothing is written: the note exists only as sound until it is answered.
  ///
  /// After answering, the staff appears — seeing where the sound lives is what
  /// ties the ear to the reading.
  @ViewBuilder
  private func listenPanel(_ card: NoteCard) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      if controller.reveal == nil {
        Button {
          tones.play(card.pitch)
        } label: {
          Label("Ouvir de novo", systemImage: "speaker.wave.2.fill")
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
      } else {
        StaffView(
          clef: card.clef,
          noteGroups: [[card.pitch]],
          states: [.done],
          staffSpace: 20)
      }
    }
    .task(id: card.pitch.midiNoteNumber) {
      // Sound it as soon as it comes up: the question *is* the sound.
      try? await Task.sleep(for: .milliseconds(250))
      tones.play(card.pitch)
    }
  }

  private var placementMarks: [StaffMark] {
    guard let reveal = controller.reveal,
      case .staffStep(let chosen) = reveal.chosen,
      case .staffStep(let expected) = reveal.expected
    else { return [] }

    return [
      StaffMark(step: chosen, state: .failed),
      StaffMark(step: expected, state: .done),
    ]
  }

  private var feedbackLine: some View {
    HStack(spacing: 10) {
      Circle().fill(feedbackColor).frame(width: 10, height: 10)
      Text(feedbackText)
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundStyle(feedbackColor)

      Spacer()

      if controller.reveal != nil {
        Button("Continuar") { controller.continueAfterReveal() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .frame(height: 26)
  }

  private var answerButtons: some View {
    HStack(spacing: 10) {
      ForEach(Array(NoteLetter.allCases.enumerated()), id: \.element) { index, letter in
        Button {
          controller.answer(.letter(letter))
        } label: {
          Text(letter.solfegeName)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(buttonTint(for: letter), in: RoundedRectangle(cornerRadius: 6))
        }
        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
        .disabled(!acceptsLetters)
      }
    }
    .opacity(acceptsLetters || controller.reveal != nil ? 1 : 0.35)
  }

  private func buttonTint(for letter: NoteLetter) -> Color {
    guard let reveal = controller.reveal else { return .clear }
    if reveal.expected == .letter(letter) { return ItemState.done.color.opacity(0.28) }
    if reveal.chosen == .letter(letter) { return ItemState.failed.color.opacity(0.28) }
    return .clear
  }

  private var acceptsLetters: Bool {
    guard controller.reveal == nil else { return false }
    switch controller.session.currentCard?.direction {
    case .nameTheNote, .hearTheNote: return true
    default: return false
    }
  }

  private var feedbackColor: Color {
    if controller.reveal != nil { return ItemState.failed.color }
    return controller.wasCorrect ? ItemState.done.color : ItemState.pending.color
  }

  private var feedbackText: String {
    guard let reveal = controller.reveal else {
      return controller.wasCorrect ? "Certo" : " "
    }

    switch (reveal.chosen, reveal.expected) {
    case (.letter(let chosen), .letter(let expected)):
      return "\(chosen.solfegeName) não — era \(expected.solfegeName)"
    case (.staffStep, .staffStep):
      return "Ali não — o \(reveal.card.pitch.solfegeWithOctave) é a verde"
    default:
      return "Não"
    }
  }
}
