import ScoreModel

/// Which lessons have been cleared, and which are open.
///
/// Lessons unlock in order: the next one opens when the one before it is done.
/// Anything already cleared stays open, so a lesson can be replayed for
/// practice without redoing the course.
public struct CourseProgress: Equatable, Sendable {
  /// Identifiers of lessons already cleared.
  public private(set) var completedIDs: Set<String>

  /// Opens every lesson, whatever has been cleared.
  ///
  /// A development affordance while the course is being built: it makes any
  /// lesson reachable without walking the trail first. It never marks anything
  /// as completed, so the earned progress stays honest underneath. Not meant to
  /// ship switched on.
  public var unlocksEverything: Bool

  /// Creates progress.
  /// - Parameters:
  ///   - completedIDs: Identifiers of lessons already cleared.
  ///   - unlocksEverything: Whether to open every lesson regardless.
  public init(completedIDs: Set<String> = [], unlocksEverything: Bool = false) {
    self.completedIDs = completedIDs
    self.unlocksEverything = unlocksEverything
  }

  /// Whether a lesson has been cleared.
  /// - Parameter lesson: The lesson to check.
  /// - Returns: `true` when it has been completed at least once.
  public func isCompleted(_ lesson: Lesson) -> Bool {
    completedIDs.contains(lesson.id)
  }

  /// Whether a lesson can be started.
  ///
  /// The first lesson is always open; the rest need the one before them.
  /// - Parameter index: Position in ``Course/lessons``.
  /// - Returns: `true` when the lesson can be started.
  public func isUnlocked(at index: Int) -> Bool {
    guard Course.lessons.indices.contains(index) else { return false }
    guard !unlocksEverything else { return true }
    guard index > 0 else { return true }
    return completedIDs.contains(Course.lessons[index - 1].id)
  }

  /// The lesson the player should take next.
  ///
  /// Once everything is cleared it stays on the last one rather than running
  /// off the end.
  public var currentIndex: Int {
    let next = Course.lessons.firstIndex { !completedIDs.contains($0.id) }
    return next ?? max(Course.lessons.count - 1, 0)
  }

  /// Records a lesson as cleared.
  /// - Parameter lesson: The lesson that was completed.
  public mutating func complete(_ lesson: Lesson) {
    completedIDs.insert(lesson.id)
  }
}
