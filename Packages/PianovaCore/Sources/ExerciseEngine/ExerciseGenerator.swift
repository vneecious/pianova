import ScoreModel

/// Builds practice sequences to play on the instrument.
public enum ExerciseGenerator {
  /// Builds a sequence of single notes drawn from a pool.
  ///
  /// Consecutive notes stay within `maxLeap` positions of each other in the
  /// pool, so early exercises move by steps instead of jumping around the
  /// keyboard. The same note never appears twice in a row: repeating a key
  /// reads as a stuck cursor rather than an exercise.
  /// - Parameters:
  ///   - pitches: The pitches to draw from, in ascending order.
  ///   - length: How many notes the sequence should have.
  ///   - maxLeap: Largest jump between consecutive notes, in pool positions.
  ///   - generator: Source of randomness, injected so tests stay deterministic.
  /// - Returns: The exercise, ready to play.
  public static func build<G: RandomNumberGenerator>(
    pitches: [Pitch],
    length: Int,
    maxLeap: Int,
    using generator: inout G
  ) -> Exercise {
    guard !pitches.isEmpty, length > 0 else { return Exercise(items: []) }
    guard pitches.count > 1 else { return Exercise(items: [ExerciseItem(pitches[0])]) }

    var indices: [Int] = [Int.random(in: pitches.indices, using: &generator)]

    while indices.count < length {
      guard let current = indices.last else { break }

      // Stay inside the leap limit, clipped to the pool, and never repeat the
      // note that was just played.
      let lower = max(pitches.startIndex, current - maxLeap)
      let upper = min(pitches.endIndex - 1, current + maxLeap)
      let candidates = (lower...upper).filter { $0 != current }
      guard let next = candidates.randomElement(using: &generator) else { break }

      indices.append(next)
    }

    return Exercise(items: indices.map { ExerciseItem(pitches[$0]) })
  }

  /// Builds a sequence of simultaneous groups: intervals or chords.
  ///
  /// Voices are stacked in thirds over the pool, which for a pool of natural
  /// notes gives the diatonic thirds and triads that methods teach first. Two
  /// voices make a third, three make a triad.
  /// - Parameters:
  ///   - pitches: The pitches to draw from, in ascending order.
  ///   - length: How many groups the sequence should have.
  ///   - voices: How many notes sound together in each group.
  ///   - generator: Source of randomness, injected so tests stay deterministic.
  /// - Returns: The exercise, ready to play.
  public static func buildHarmony<G: RandomNumberGenerator>(
    pitches: [Pitch],
    length: Int,
    voices: Int,
    using generator: inout G
  ) -> Exercise {
    guard length > 0, voices > 0 else { return Exercise(items: []) }

    // Each extra voice sits two pool positions higher, so the highest voice
    // needs that much room above the root.
    let reach = (voices - 1) * 2
    guard pitches.count > reach else { return Exercise(items: []) }

    let roots = 0...(pitches.count - 1 - reach)
    let items = (0..<length)
      .map { _ -> ExerciseItem in
        let root = Int.random(in: roots, using: &generator)
        let stacked = (0..<voices).map { pitches[root + $0 * 2] }
        return ExerciseItem(pitches: Set(stacked))
      }

    return Exercise(items: items)
  }

  /// Builds a sequence for both hands: one note from each, sounding together.
  /// - Parameters:
  ///   - rightHand: Pitches the right hand may play.
  ///   - leftHand: Pitches the left hand may play.
  ///   - length: How many groups the sequence should have.
  ///   - generator: Source of randomness, injected so tests stay deterministic.
  /// - Returns: The exercise, ready to play.
  public static func buildTwoHands<G: RandomNumberGenerator>(
    rightHand: [Pitch],
    leftHand: [Pitch],
    length: Int,
    using generator: inout G
  ) -> Exercise {
    guard length > 0, !rightHand.isEmpty, !leftHand.isEmpty else {
      return Exercise(items: [])
    }

    let items = (0..<length)
      .compactMap { _ -> ExerciseItem? in
        guard let high = rightHand.randomElement(using: &generator),
          let low = leftHand.randomElement(using: &generator)
        else { return nil }
        return ExerciseItem(pitches: [high, low])
      }

    return Exercise(items: items)
  }
}
