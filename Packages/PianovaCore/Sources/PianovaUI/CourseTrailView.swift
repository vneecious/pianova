import Course
import SwiftUI

/// The course drawn as a path you walk down.
///
/// Vertical and scrolling, so the road ahead is visible without a legend: what
/// is behind you, where you are, and what is still closed.
public struct CourseTrailView: View {
  /// How far the player has got.
  public let progress: CourseProgress

  /// Called with the lesson that was picked.
  public let onPick: (Lesson) -> Void

  /// Creates the trail.
  /// - Parameters:
  ///   - progress: How far the player has got.
  ///   - onPick: Called with the lesson that was picked.
  public init(progress: CourseProgress, onPick: @escaping (Lesson) -> Void) {
    self.progress = progress
    self.onPick = onPick
  }

  /// How far each stop leans from the centre, in points.
  private let sway: CGFloat = 76

  /// The trail.
  public var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(Array(Course.lessons.enumerated()), id: \.element.id) { index, lesson in
          if index > 0 {
            connector(to: index)
          }
          if index == 0 || Course.lessons[index - 1].block != lesson.block {
            blockHeader(lesson.block)
          }
          stop(lesson, at: index)
        }
      }
      .padding(.vertical, 28)
      .frame(maxWidth: .infinity)
    }
  }

  /// Stops lean left and right down the page, so the eye follows a path
  /// instead of a list.
  private func offset(for index: Int) -> CGFloat {
    switch index % 4 {
    case 0: return 0
    case 1: return sway
    case 2: return 0
    default: return -sway
    }
  }

  /// The syllabus block a stretch of the trail belongs to.
  private func blockHeader(_ block: TheoryTopic) -> some View {
    HStack(spacing: 8) {
      Text(block.letter)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(Color.primary.opacity(0.35), in: Circle())

      Text(block.title)
        .font(.system(size: 15, weight: .semibold))

      Spacer()
    }
    .frame(maxWidth: 320, alignment: .leading)
    .padding(.top, 22)
    .padding(.bottom, 14)
  }

  private func connector(to index: Int) -> some View {
    let from = offset(for: index - 1)
    let to = offset(for: index)

    return Path { path in
      path.move(to: CGPoint(x: from, y: 0))
      path.addQuadCurve(
        to: CGPoint(x: to, y: 46),
        control: CGPoint(x: (from + to) / 2, y: 23))
    }
    .stroke(
      progress.isUnlocked(at: index) ? ItemState.done.color.opacity(0.5) : lockedInk,
      style: StrokeStyle(lineWidth: 4, lineCap: .round)
    )
    .frame(height: 46)
  }

  private func stop(_ lesson: Lesson, at index: Int) -> some View {
    let unlocked = progress.isUnlocked(at: index)
    let done = progress.isCompleted(lesson)
    let current = index == progress.currentIndex

    return Button {
      if unlocked { onPick(lesson) }
    } label: {
      VStack(spacing: 8) {
        ZStack {
          Circle()
            .fill(nodeFill(done: done, current: current, unlocked: unlocked))
            .frame(width: 62, height: 62)
            .shadow(
              color: current ? ItemState.current.color.opacity(0.35) : .clear,
              radius: 10, y: 3)

          if current && !done {
            Circle()
              .strokeBorder(ItemState.current.color.opacity(0.35), lineWidth: 3)
              .frame(width: 76, height: 76)
          }

          Image(systemName: symbol(lesson, done: done, unlocked: unlocked))
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(unlocked ? .white : Color.secondary)
        }

        VStack(spacing: 2) {
          Text(lesson.title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(unlocked ? .primary : .secondary)
          Text(lesson.subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(width: 190)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!unlocked)
    .offset(x: offset(for: index))
  }

  private func symbol(_ lesson: Lesson, done: Bool, unlocked: Bool) -> String {
    if !unlocked { return "lock.fill" }
    if done { return "checkmark" }
    if lesson.hasSong { return "music.note" }
    return "pianokeys"
  }

  private func nodeFill(done: Bool, current: Bool, unlocked: Bool) -> Color {
    if !unlocked { return Color.primary.opacity(0.07) }
    if current && !done { return ItemState.current.color }
    if done { return ItemState.done.color }
    return ItemState.current.color.opacity(0.75)
  }

  private var lockedInk: Color { Color.primary.opacity(0.12) }
}
