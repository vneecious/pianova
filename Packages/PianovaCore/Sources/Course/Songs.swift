import ScoreModel

/// Pieces the course can ask for.
///
/// Public domain only. The melodies are written out here rather than lifted
/// from any method book.
public enum Songs {
  /// *Ode to Joy*, the theme from Beethoven's Ninth Symphony, 1824.
  ///
  /// Simplified to the right-hand melody in C major, which stays inside a
  /// five-finger position from middle C and never leaves the treble staff.
  public static let odeToJoy = Song(
    title: "Hino à Alegria",
    composer: "Beethoven",
    clef: .treble,
    notes: [
      64, 64, 65, 67, 67, 65, 64, 62,
      60, 60, 62, 64, 64, 62, 62,
      64, 64, 65, 67, 67, 65, 64, 62,
      60, 60, 62, 64, 62, 60, 60,
    ]
    .map { Pitch(UInt8($0)) })

  /// *Twinkle, Twinkle, Little Star*, a traditional melody.
  ///
  /// The first phrase only, in C major, five-finger position.
  public static let twinkle = Song(
    title: "Brilha, Brilha, Estrelinha",
    composer: "Tradicional",
    clef: .treble,
    notes: [
      60, 60, 67, 67, 69, 69, 67,
      65, 65, 64, 64, 62, 62, 60,
    ]
    .map { Pitch(UInt8($0)) })

  /// *Mary Had a Little Lamb*, a traditional melody.
  ///
  /// Sits entirely in a five-finger position from middle C, which is why nearly
  /// every method uses it as the first real tune.
  public static let maryHadALittleLamb = Song(
    title: "Mary Had a Little Lamb",
    composer: "Tradicional",
    clef: .treble,
    notes: [
      64, 62, 60, 62, 64, 64, 64,
      62, 62, 62, 64, 67, 67,
      64, 62, 60, 62, 64, 64, 64, 64, 62, 62, 64, 62, 60,
    ]
    .map { Pitch(UInt8($0)) })

  /// *Au Clair de la Lune*, a traditional French melody.
  ///
  /// Four notes only, Dó to Mi, so it can be played before the hand ever moves.
  public static let auClairDeLaLune = Song(
    title: "Au Clair de la Lune",
    composer: "Tradicional",
    clef: .treble,
    notes: [60, 60, 60, 62, 64, 62, 60, 64, 62, 62, 60].map { Pitch(UInt8($0)) })

  /// *Au Clair de la Lune*, an octave down for the left hand.
  ///
  /// The same tune read in bass clef: the point is that the reading changes
  /// while the shape under the hand does not.
  public static let auClairDeLaLuneBass = Song(
    title: "Au Clair de la Lune (mão esquerda)",
    composer: "Tradicional",
    clef: .bass,
    notes: [48, 48, 48, 50, 52, 50, 48, 52, 50, 50, 48].map { Pitch(UInt8($0)) })

  /// *Jingle Bells*, James Pierpont, 1857.
  ///
  /// The chorus phrase, kept inside the five-finger position.
  public static let jingleBells = Song(
    title: "Jingle Bells",
    composer: "Pierpont",
    clef: .treble,
    notes: [
      64, 64, 64, 64, 64, 64,
      64, 67, 60, 62, 64,
      65, 65, 65, 65, 65, 64, 64, 64,
      64, 62, 62, 64, 62, 67,
    ]
    .map { Pitch(UInt8($0)) })

  /// *Au Clair de la Lune* for both hands.
  ///
  /// The melody unchanged, with the left hand holding the root underneath: the
  /// tonic under the phrases that rest, the dominant under the ones that move.
  /// One left hand note for each melody note, so no rhythm is implied.
  public static let auClairDeLaLuneTwoHands = Song(
    title: "Au Clair de la Lune (duas mãos)",
    composer: "Tradicional",
    clef: .treble,
    notes: [60, 60, 60, 62, 64, 62, 60, 64, 62, 62, 60].map { Pitch(UInt8($0)) },
    leftHandNotes: [48, 48, 48, 43, 48, 43, 48, 48, 43, 43, 48].map { Pitch(UInt8($0)) })

  /// *Frère Jacques*, a traditional round.
  ///
  /// Kept in C major and within a five-finger position.
  public static let frereJacques = Song(
    title: "Frère Jacques",
    composer: "Tradicional",
    clef: .treble,
    notes: [
      60, 62, 64, 60,
      60, 62, 64, 60,
      64, 65, 67,
      64, 65, 67,
    ]
    .map { Pitch(UInt8($0)) })
}
