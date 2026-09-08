import Course
import SwiftUI

/// Pick any unlocked lesson and repeat it, without touching the course.
///
/// The trail decides what comes next; this decides what you feel like drilling.
struct FreePracticeView: View {
  /// How far the player has got.
  let progress: CourseProgress

  /// Called with the lesson that was picked.
  let onPick: (Lesson) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if unlocked.isEmpty {
          Text("Complete a primeira lição para liberar a prática livre.")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.top, 12)
        }

        ForEach(unlocked, id: \.id) { lesson in
          row(lesson)
        }
      }
      .padding(.horizontal, 32)
      .padding(.vertical, 24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var unlocked: [Lesson] {
    Course.lessons.enumerated()
      .filter { progress.isUnlocked(at: $0.offset) }
      .map(\.element)
  }

  private func row(_ lesson: Lesson) -> some View {
    Button {
      onPick(lesson)
    } label: {
      HStack(spacing: 14) {
        Image(systemName: lesson.hasSong ? "music.note" : "pianokeys")
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(
            progress.isCompleted(lesson) ? ItemState.done.color : ItemState.current.color,
            in: RoundedRectangle(cornerRadius: 9))

        VStack(alignment: .leading, spacing: 2) {
          Text(lesson.title)
            .font(.system(size: 15, weight: .medium))
          Text(lesson.subtitle)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text(summary(lesson))
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
      .contentShape(RoundedRectangle(cornerRadius: 11))
    }
    .buttonStyle(.plain)
  }

  private func summary(_ lesson: Lesson) -> String {
    let cards = lesson.steps.filter {
      switch $0 {
      case .cards, .theory, .reading, .ear: return true
      default: return false
      }
    }
    let plays = lesson.steps.filter {
      switch $0 {
      case .play, .harmony, .chromatic, .bothHands, .rhythm: return true
      default: return false
      }
    }
    let songs = lesson.steps.filter {
      guard case .song = $0 else { return false }
      return true
    }

    var parts: [String] = []
    if !cards.isEmpty { parts.append("\(cards.count) teoria") }
    if !plays.isEmpty { parts.append("\(plays.count) prática") }
    if !songs.isEmpty { parts.append("\(songs.count) música") }
    return parts.joined(separator: " · ")
  }
}
