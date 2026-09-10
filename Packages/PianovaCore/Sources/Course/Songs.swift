import ScoreModel

/// Pieces the course can ask for.
///
/// Public domain only, and written out here rather than lifted from any method
/// book. Every one carries its time signature, its key and a figure for every
/// note: a piece stored as bare pitches draws as a row of note heads, which is
/// not a score and cannot be read from.
public enum Songs {
  /// One right hand note.
  private static func n(_ p: Int, _ v: NoteValue = .quarter, _ dot: Bool = false) -> ScoreNote {
    ScoreNote(Pitch(UInt8(p)), v, dotted: dot)
  }

  /// A rest.
  private static func z(_ v: NoteValue) -> ScoreNote { .rest(v) }

  /// Notes sounding together.
  private static func ch(_ ps: [Int], _ v: NoteValue, _ dot: Bool = false) -> ScoreNote {
    ScoreNote(pitches: ps.map { Pitch(UInt8($0)) }, duration: Duration(v, dotted: dot))
  }

  /// One bar.
  private static func m(_ notes: ScoreNote...) -> Measure { Measure(notes) }

  /// A left hand of one held note per bar.
  private static func drone(_ roots: [Int], _ v: NoteValue, _ dot: Bool = false) -> Part {
    Part(clef: .bass, measures: roots.map { Measure([n($0, v, dot)]) })
  }

  // MARK: - Units 1 to 5

  /// *Au Clair de la Lune*, a traditional French melody.
  ///
  /// Four notes only, so it can be played before the hand ever moves, and the
  /// rhythm is three crotchets and a minim — the first rhythm worth counting.
  public static let auClairDeLaLune = Score(
    title: "Au Clair de la Lune", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(60), n(60), n(60), n(62)),
        m(n(64, .half), n(62, .half)),
        m(n(60), n(64), n(62), n(62)),
        m(n(60, .whole)),
      ]))

  /// *Au Clair de la Lune*, an octave down for the left hand.
  ///
  /// The same tune read in bass clef: the reading changes, the shape under the
  /// hand does not.
  public static let auClairDeLaLuneBass = Score(
    title: "Au Clair de la Lune (mão esquerda)", composer: "Tradicional",
    rightHand: Part(
      clef: .bass,
      measures: [
        m(n(48), n(48), n(48), n(50)),
        m(n(52, .half), n(50, .half)),
        m(n(48), n(52), n(50), n(50)),
        m(n(48, .whole)),
      ]))

  /// *Au Clair de la Lune* for both hands.
  ///
  /// The melody unchanged, with the left hand holding one root per bar: the
  /// tonic under the phrases that rest, the dominant under the one that moves.
  public static let auClairDeLaLuneTwoHands = Score(
    title: "Au Clair de la Lune (duas mãos)", composer: "Tradicional",
    rightHand: auClairDeLaLune.rightHand,
    leftHand: drone([48, 43, 43, 48], .whole))

  /// *Mary Had a Little Lamb*, a traditional melody.
  ///
  /// Sits entirely in a five-finger position from middle C, which is why nearly
  /// every method uses it as the first real tune.
  public static let maryHadALittleLamb = Score(
    title: "Mary Had a Little Lamb", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(64), n(62), n(60), n(62)),
        m(n(64), n(64), n(64, .half)),
        m(n(62), n(62), n(62, .half)),
        m(n(64), n(67), n(67, .half)),
        m(n(64), n(62), n(60), n(62)),
        m(n(64), n(64), n(64), n(64)),
        m(n(62), n(62), n(64), n(62)),
        m(n(60, .whole)),
      ]))

  /// *Twinkle, Twinkle, Little Star*, a traditional melody.
  public static let twinkle = Score(
    title: "Brilha, Brilha, Estrelinha", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(60), n(60), n(67), n(67)),
        m(n(69), n(69), n(67, .half)),
        m(n(65), n(65), n(64), n(64)),
        m(n(62), n(62), n(60, .half)),
      ]))

  /// *Frère Jacques*, a traditional round.
  public static let frereJacques = Score(
    title: "Frère Jacques", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(60), n(62), n(64), n(60)),
        m(n(60), n(62), n(64), n(60)),
        m(n(64), n(65), n(67, .half)),
        m(n(64), n(65), n(67, .half)),
      ]))

  /// *Jingle Bells*, James Pierpont, 1857.
  public static let jingleBells = Score(
    title: "Jingle Bells", composer: "Pierpont",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(64), n(64), n(64, .half)),
        m(n(64), n(64), n(64, .half)),
        m(n(64), n(67), n(60), n(62)),
        m(n(64, .whole)),
        m(n(65), n(65), n(65), n(65)),
        m(n(65), n(64), n(64), n(64, .eighth), n(64, .eighth)),
        m(n(64), n(62), n(62), n(64)),
        m(n(62, .half), n(67, .half)),
      ]))

  /// *Lightly Row*, a traditional German melody.
  ///
  /// Uses all five notes of the C position and never leaves them.
  public static let lightlyRow = Score(
    title: "Lightly Row", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(67), n(64), n(64, .half)),
        m(n(65), n(62), n(62, .half)),
        m(n(60), n(62), n(64), n(65)),
        m(n(67), n(67), n(67, .half)),
        m(n(67), n(64), n(64, .half)),
        m(n(65), n(62), n(62, .half)),
        m(n(60), n(64), n(67), n(67)),
        m(n(60, .whole)),
      ]))

  /// *Ode to Joy*, the theme from Beethoven's Ninth Symphony, 1824.
  ///
  /// The dotted crotchet in the last bar is the first dot the course meets in a
  /// piece, and it is what makes the phrase land instead of stopping.
  public static let odeToJoy = Score(
    title: "Hino à Alegria", composer: "Beethoven",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(64), n(64), n(65), n(67)),
        m(n(67), n(65), n(64), n(62)),
        m(n(60), n(60), n(62), n(64)),
        m(n(64, .quarter, true), n(62, .eighth), n(62, .half)),
        m(n(64), n(64), n(65), n(67)),
        m(n(67), n(65), n(64), n(62)),
        m(n(60), n(60), n(62), n(64)),
        m(n(62, .quarter, true), n(60, .eighth), n(60, .half)),
      ]))

  /// *Row, Row, Row Your Boat*, traditional, read in the bass clef.
  public static let rowYourBoat = Score(
    title: "Row, Row, Row Your Boat", composer: "Tradicional",
    rightHand: Part(
      clef: .bass,
      measures: [
        m(n(48), n(48), n(48), n(50)),
        m(n(52, .half), n(52, .half)),
        m(n(52), n(50), n(52), n(53)),
        m(n(55, .whole)),
      ]))

  /// The Largo theme from Dvořák's *New World* Symphony, 1893.
  ///
  /// Moves almost entirely by thirds, which is why it arrives exactly when
  /// thirds are being read on the staff.
  public static let newWorldTheme = Score(
    title: "Sinfonia do Novo Mundo", composer: "Dvořák",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(64), n(67), n(67), n(64)),
        m(n(62), n(60), n(62, .half)),
        m(n(64), n(67), n(64, .half)),
        m(n(62, .whole)),
      ]))

  /// *London Bridge*, a traditional English melody.
  ///
  /// The first piece where two quavers share one beat inside a bar of
  /// crotchets, which is exactly the skill it is placed to train.
  public static let londonBridge = Score(
    title: "London Bridge", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(67), n(69, .eighth), n(67, .eighth), n(65), n(64)),
        m(n(62), n(64), n(65, .half)),
        m(n(64), n(65), n(67, .half)),
        m(n(67), n(69, .eighth), n(67, .eighth), n(65), n(64)),
        m(n(65), n(67), n(62, .half)),
        m(n(67), n(64), n(60, .half)),
      ]))

  // MARK: - Unit 6: eighth notes, upbeat, fermata

  /// *Happy Birthday to You*, the traditional melody.
  ///
  /// In the public domain since 2016. Written in C with the upbeat on the
  /// dominant, which is what keeps the whole tune on white keys — set from the
  /// tonic instead it needs a flat in the last phrase.
  ///
  /// The upbeat is the point of placing it here: the piece starts before the
  /// bar does, and the first bar is short by design.
  public static let happyBirthday = Score(
    title: "Parabéns a Você", composer: "Tradicional",
    timeSignature: .threeFour,
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(67, .eighth), n(67, .eighth)),
        m(n(69), n(67), n(72)),
        m(n(71, .half), n(67, .eighth), n(67, .eighth)),
        m(n(69), n(67), n(74)),
        m(n(72, .half), n(67, .eighth), n(67, .eighth)),
        m(n(79), n(76), n(72)),
        m(n(71), n(69), n(77, .eighth), n(77, .eighth)),
        m(n(76), n(72), n(74)),
        m(n(72, .half), z(.quarter)),
      ]),
    hasPickup: true)

  /// *Taps*, the American bugle call, 1862.
  ///
  /// Three notes of a bugle, so the reading is trivial and all the attention
  /// goes to the dotted rhythm, which is the whole of this piece.
  public static let taps = Score(
    title: "Toque de Silêncio", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(60, .eighth), n(60, .eighth), n(65, .half), z(.quarter)),
        m(n(60, .eighth), n(65, .eighth), n(72, .half), z(.quarter)),
        m(n(60, .eighth), n(65, .eighth), n(72, .half), z(.quarter)),
        m(n(72, .whole)),
      ]))

  // MARK: - Unit 7: the treble spaces

  /// *Reveille*, the American bugle call.
  ///
  /// Built on the notes of the C chord, so it doubles as an arpeggio study.
  public static let reveille = Score(
    title: "Alvorada", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(60, .eighth), n(64, .eighth), n(60, .eighth), n(64, .eighth), n(60), n(64)),
        m(n(67), n(64), n(60, .half)),
        m(n(60, .eighth), n(64, .eighth), n(60, .eighth), n(64, .eighth), n(60), n(64)),
        m(n(67), n(64), n(60, .half)),
      ]))

  /// *Aura Lee*, an American melody of 1861.
  ///
  /// Moves by step and third inside one hand position, and is the first piece
  /// here whose phrases really need a legato line.
  public static let auraLee = Score(
    title: "Aura Lee", composer: "Poulton",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(60, .half), n(62, .half)),
        m(n(64), n(65), n(67, .half)),
        m(n(67), n(65), n(64), n(62)),
        m(n(64, .half), n(65, .half)),
        m(n(64), n(62), n(60, .half)),
        m(n(62), n(60), n(60, .half)),
      ]))

  // MARK: - Unit 8: the upper C pentascale

  /// *When the Saints Go Marching In*, a traditional spiritual.
  ///
  /// Written an octave above middle C: the same five-finger shape, read higher
  /// on the staff. The upbeat of three crotchets is unmistakable.
  public static let whenTheSaints = Score(
    title: "When the Saints Go Marching In", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(72), n(76), n(77)),
        m(n(79, .whole)),
        m(n(72), n(76), n(77), n(79)),
        m(n(79, .half), z(.half)),
        m(n(72), n(76), n(77), n(79)),
        m(n(76), n(72), n(76), n(74)),
        m(n(76, .whole)),
        m(n(74, .half), n(72, .half)),
      ]),
    hasPickup: true)

  /// *Michael, Row the Boat Ashore*, a traditional spiritual.
  public static let michaelRow = Score(
    title: "Michael, Row the Boat Ashore", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(72), n(76), n(77), n(76)),
        m(n(77), n(79, .half), n(77)),
        m(n(76), n(72), n(74), n(72)),
        m(n(72, .whole)),
        m(n(72), n(76), n(77), n(76)),
        m(n(74), n(72, .half), z(.quarter)),
      ]))

  // MARK: - Unit 9: the G pentascale

  /// *Twinkle, Twinkle, Little Star* in the G pentascale.
  ///
  /// The melody the course already knows in C, moved to G. Hearing that it is
  /// unchanged while every written note moved is the lesson.
  public static let twinkleInG = Score(
    title: "Brilha, Brilha (em Sol)", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(67), n(67), n(74), n(74)),
        m(n(76), n(76), n(74, .half)),
        m(n(72), n(72), n(71), n(71)),
        m(n(69), n(69), n(67, .half)),
      ]))

  /// *Ode to Joy* in the G pentascale.
  public static let odeToJoyInG = Score(
    title: "Hino à Alegria (em Sol)", composer: "Beethoven",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(71), n(71), n(72), n(74)),
        m(n(74), n(72), n(71), n(69)),
        m(n(67), n(67), n(69), n(71)),
        m(n(71, .quarter, true), n(69, .eighth), n(69, .half)),
      ]))

  // MARK: - Units 10 and 11: accidentals and wider intervals

  /// *Greensleeves*, an English melody first printed in 1580.
  ///
  /// The first piece in the course with a key signature, and it earns it: the
  /// raised sixth is what gives the tune its colour.
  public static let greensleeves = Score(
    title: "Greensleeves", composer: "Tradicional",
    timeSignature: .threeFour, key: .g,
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(69, .quarter)),
        m(n(72, .half), n(74)),
        m(n(76, .quarter, true), n(77, .eighth), n(76)),
        m(n(74, .half), n(71)),
        m(n(67, .quarter, true), n(69, .eighth), n(71)),
        m(n(72, .half), n(69)),
        m(n(69, .quarter, true), n(68, .eighth), n(69)),
        m(n(71, .half), n(68)),
        m(n(69, .half, true)),
      ]),
    hasPickup: true)

  /// *Nobody Knows the Trouble I've Seen*, a traditional spiritual.
  ///
  /// Opens on a leap of a fourth and keeps returning to it, so the interval is
  /// heard well before it is named.
  public static let nobodyKnows = Score(
    title: "Nobody Knows the Trouble I've Seen", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(67), n(72), n(72, .half)),
        m(n(71), n(72), n(74, .half)),
        m(n(72, .half), n(67, .half)),
        m(n(69), n(72), n(71), n(69)),
        m(n(67, .whole)),
      ]))

  /// *Promenade*, from Mussorgsky's *Pictures at an Exhibition*, 1874.
  ///
  /// Fourths and fifths in the melody itself, which is why the unit on those
  /// intervals ends here.
  public static let promenade = Score(
    title: "Promenade", composer: "Mussorgsky",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(72), n(74), n(76), n(72)),
        m(n(74), n(76, .half), z(.quarter)),
        m(n(79), n(77), n(76), n(74)),
        m(n(72), n(74), n(76, .half)),
        m(n(72, .whole)),
      ]))

  // MARK: - Units 12 to 16: scales, chords, two hands

  /// *Home on the Range*, an American melody of 1873.
  ///
  /// A waltz whose melody outlines the primary chords, so it sits over I-IV-V7
  /// in the left hand.
  public static let homeOnTheRange = Score(
    title: "Home on the Range", composer: "Tradicional",
    timeSignature: .threeFour,
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(60, .quarter)),
        m(n(64), n(67), n(72)),
        m(n(71, .half), n(69)),
        m(n(67, .half), n(65)),
        m(n(65), n(64), n(62)),
        m(n(60, .half, true)),
      ]),
    leftHand: Part(
      clef: .bass,
      measures: [
        m(z(.quarter)),
        m(ch([48, 55], .half, true)),
        m(ch([43, 50], .half, true)),
        m(ch([41, 48], .half, true)),
        m(ch([43, 50], .half, true)),
        m(ch([48, 55], .half, true)),
      ]),
    hasPickup: true)

  /// *Trumpet Voluntary*, Jeremiah Clarke, around 1700.
  ///
  /// The tune leans on the dominant seventh at every phrase end, which is
  /// exactly the chord the unit introduces.
  public static let trumpetVoluntary = Score(
    title: "Trumpet Voluntary", composer: "Clarke",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(72, .half), n(72), n(74)),
        m(n(76), n(77), n(79, .half)),
        m(n(77), n(76), n(74, .half)),
        m(n(74), n(76), n(74), n(72)),
        m(n(72, .whole)),
      ]))

  /// *Minuet in G*, from the Notebook for Anna Magdalena Bach, 1725.
  ///
  /// Attributed for two centuries to Bach and now credited to Christian
  /// Petzold. The first piece in the course written in a key signature, with
  /// the left hand walking rather than holding.
  public static let minuetInG = Score(
    title: "Minueto em Sol", composer: "Petzold",
    timeSignature: .threeFour, key: .g,
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(74), n(67, .eighth), n(69, .eighth), n(71, .eighth), n(72, .eighth)),
        m(n(74), n(67), n(67)),
        m(n(79), n(72, .eighth), n(74, .eighth), n(76, .eighth), n(77, .eighth)),
        m(n(79), n(67), n(67)),
      ]),
    leftHand: Part(
      clef: .bass,
      measures: [
        m(n(55), n(59), n(62)),
        m(n(59), n(55, .half)),
        m(n(52), n(55), n(59)),
        m(n(55), n(50, .half)),
      ]))

  /// *Amazing Grace*, the melody published as *New Britain* in 1835.
  ///
  /// In G, over the primary chords the final unit teaches. The upbeat is a
  /// single crotchet, the shortest anacrusis in the course.
  public static let amazingGrace = Score(
    title: "Amazing Grace", composer: "Tradicional",
    timeSignature: .threeFour, key: .g,
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(62, .quarter)),
        m(n(67, .half), n(71, .eighth), n(67, .eighth)),
        m(n(71, .half), n(69)),
        m(n(67, .half), n(64)),
        m(n(62, .half, true)),
        m(n(62, .half), n(67, .eighth), n(71, .eighth)),
        m(n(71, .half), n(69)),
        m(n(74, .half, true)),
      ]),
    leftHand: Part(
      clef: .bass,
      measures: [
        m(z(.quarter)),
        m(ch([43, 50], .half, true)),
        m(ch([43, 50], .half, true)),
        m(ch([48, 55], .half, true)),
        m(ch([43, 50], .half, true)),
        m(ch([43, 50], .half, true)),
        m(ch([38, 45], .half, true)),
        m(ch([43, 50], .half, true)),
      ]),
    hasPickup: true)

  /// *For He's a Jolly Good Fellow*, a traditional melody.
  ///
  /// Read from a lead sheet in the last unit: the melody written out, the
  /// harmony named by chord symbol and built by the player.
  public static let jollyGoodFellow = Score(
    title: "For He's a Jolly Good Fellow", composer: "Tradicional",
    key: .g,
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(67, .quarter)),
        m(n(72, .half), n(72), n(74)),
        m(n(72), n(71), n(69, .half)),
        m(n(69), n(71), n(72, .half)),
        m(n(71), n(69), n(71), n(72)),
        m(n(67, .whole)),
      ]),
    leftHand: Part(
      clef: .bass,
      measures: [
        m(z(.quarter)),
        m(ch([48, 55], .whole)),
        m(ch([53, 60], .whole)),
        m(ch([48, 55], .whole)),
        m(ch([55, 62], .whole)),
        m(ch([48, 55], .whole)),
      ]),
    hasPickup: true)

  /// *The Carnival of Venice*, a traditional Neapolitan melody.
  ///
  /// The review piece: it needs the C scale, both hands and the primary chords,
  /// which is everything the course built.
  public static let carnivalOfVenice = Score(
    title: "O Carnaval de Veneza", composer: "Tradicional",
    rightHand: Part(
      clef: .treble,
      measures: [
        m(n(67, .eighth), n(65, .eighth), n(64), n(65), n(67)),
        m(n(67, .half), z(.half)),
        m(n(65, .eighth), n(65, .eighth), n(67), n(71), n(71)),
        m(n(71, .half), z(.half)),
        m(n(67, .eighth), n(65, .eighth), n(64), n(65), n(67)),
        m(n(67), n(65), n(65), n(67)),
        m(n(65, .half), n(64, .half)),
        m(n(64, .whole)),
      ]),
    leftHand: Part(
      clef: .bass,
      measures: [
        m(ch([48, 55], .whole)),
        m(ch([48, 55], .whole)),
        m(ch([43, 50], .whole)),
        m(ch([43, 50], .whole)),
        m(ch([48, 55], .whole)),
        m(ch([48, 55], .whole)),
        m(ch([43, 50], .half), ch([48, 55], .half)),
        m(ch([48, 55], .whole)),
      ]))

  /// Every piece the course can schedule.
  ///
  /// Listing them here is what lets one test walk the lot and check that every
  /// bar fills — which is the check that a hand-written score most needs.
  public static let all: [Score] = [
    auClairDeLaLune, auClairDeLaLuneBass, auClairDeLaLuneTwoHands, maryHadALittleLamb,
    twinkle, frereJacques, jingleBells, lightlyRow, odeToJoy, rowYourBoat,
    newWorldTheme, londonBridge, happyBirthday, taps, reveille, auraLee,
    whenTheSaints, michaelRow, twinkleInG, odeToJoyInG, greensleeves, nobodyKnows,
    promenade, homeOnTheRange, trumpetVoluntary, minuetInG, amazingGrace,
    jollyGoodFellow, carnivalOfVenice,
  ]
}
