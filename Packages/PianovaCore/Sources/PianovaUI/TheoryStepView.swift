import CoreText
import Course
import Progress
import SwiftUI

/// A round of theory questions inside a lesson.
///
/// Shows the real music symbol when the question has one: a note value is
/// learned by seeing the figure, not by reading its name.
struct TheoryStepView: View {
  @StateObject private var controller: TheoryRoundController

  private let onFinished: () -> Void

  private let profile: ProfileController

  init(
    lesson: Lesson, count: Int, profile: ProfileController, onFinished: @escaping () -> Void
  ) {
    self.profile = profile
    // Only what has already been taught, the lesson's own pages first, then
    // earlier ones as review. Shuffled within each group so the order varies
    // without ever reaching past what was read.
    let eligible = Course.eligibleQuestions(for: lesson)
    let own = Set(lesson.readingIDs)
    let questions = Array(
      (eligible.filter { own.contains($0.noteID) }.shuffled()
        + eligible.filter { !own.contains($0.noteID) }.shuffled())
        .prefix(count))

    _controller = StateObject(wrappedValue: TheoryRoundController(questions: questions))
    self.onFinished = onFinished
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      if let question = controller.displayedQuestion {
        header(question)
        if !question.glyph.isEmpty {
          GlyphView(glyph: question.glyph)
        }
        options(question)
      }

      feedback
      Spacer(minLength: 0)
    }
    .onAppear {
      controller.onFinished = onFinished
      controller.onAnswered = { question, wasCorrect in
        profile.recordTheory(question.id, wasCorrect: wasCorrect)
      }
    }
  }

  private func header(_ question: TheoryQuestion) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(question.prompt)
        .font(.system(size: 21, weight: .semibold))
        .fixedSize(horizontal: false, vertical: true)

      Spacer()

      Text("\(controller.remainingCount) restantes")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
  }

  private func options(_ question: TheoryQuestion) -> some View {
    VStack(spacing: 8) {
      ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
        Button {
          controller.answer(index)
        } label: {
          HStack {
            Text(option)
              .font(.system(size: 15, weight: .medium))
            Spacer()
          }
          .padding(.horizontal, 14)
          .frame(minHeight: 46)
          .frame(maxWidth: .infinity)
          .background(tint(index, in: question), in: RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
          )
          // Without this the tap only lands on the text itself: padding,
          // spacers and backgrounds are drawn but not hit-tested.
          .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(controller.reveal != nil)
      }
    }
  }

  private func tint(_ index: Int, in question: TheoryQuestion) -> Color {
    guard let reveal = controller.reveal else { return .clear }
    if index == question.correctIndex { return ItemState.done.color.opacity(0.25) }
    if index == reveal.chosenIndex { return ItemState.failed.color.opacity(0.25) }
    return .clear
  }

  private var feedback: some View {
    HStack(spacing: 10) {
      Circle().fill(feedbackColor).frame(width: 10, height: 10)
      Text(feedbackText)
        .font(.system(size: 14))
        .foregroundStyle(feedbackColor)
        .fixedSize(horizontal: false, vertical: true)

      Spacer()

      if controller.reveal != nil {
        Button("Continuar") { controller.continueAfterReveal() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .frame(minHeight: 26)
  }

  private var feedbackColor: Color {
    guard let reveal = controller.reveal else {
      return controller.wasCorrect ? ItemState.done.color : ItemState.pending.color
    }
    return reveal.wasRight ? ItemState.done.color : ItemState.failed.color
  }

  private var feedbackText: String {
    guard let reveal = controller.reveal else {
      return controller.wasCorrect ? "Certo" : " "
    }
    return reveal.explanation
  }
}

/// One music symbol, drawn in Bravura at a readable size.
private struct GlyphView: View {
  @Environment(\.colorScheme) private var colorScheme

  let glyph: String

  var body: some View {
    Canvas { context, size in
      let font = Bravura.font(staffSpace: 22)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: PlatformColor.staffInk(colorScheme),
      ]
      let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: glyph, attributes: attributes))
      let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

      context.withCGContext { cgContext in
        cgContext.saveGState()
        cgContext.textMatrix = .identity
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1, y: -1)
        cgContext.textPosition = CGPoint(x: max((size.width - width) / 2, 0), y: 34)
        CTLineDraw(line, cgContext)
        cgContext.restoreGState()
      }
    }
    .frame(height: 110)
    .frame(maxWidth: .infinity)
    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
  }
}
