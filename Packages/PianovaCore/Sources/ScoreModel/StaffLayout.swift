import CoreGraphics

/// Where the columns of a staff sit horizontally.
///
/// One source of truth for the across-the-page maths. A playhead drawn from its
/// own arithmetic will never line up with the note heads; drawing both from
/// here is what makes them agree.
public struct StaffLayout: Equatable, Sendable {
  /// Distance between two staff lines, in points.
  public let staffSpace: CGFloat

  /// Full width available to the staff.
  public let width: CGFloat

  /// How many columns of notes are drawn.
  public let columnCount: Int

  /// Room reserved after the clef for the key and time signatures.
  ///
  /// Zero for a bare reading staff. When a real score is drawn the notes have
  /// to start *after* the signatures, or the first note lands on top of them.
  public let preamble: CGFloat

  /// Minimum distance between two columns, in staff spaces.
  ///
  /// Below this the note heads start to touch and the stems collide. Squeezing
  /// a whole piece into the screen width produces exactly that, which is why
  /// the music scrolls instead of shrinking.
  public static let minimumSpacing: CGFloat = 2.4

  /// Where the moving cursor is held, as a fraction across the note area.
  ///
  /// Left of centre on purpose: reading is looking ahead, so most of what is
  /// visible has to be music not yet played.
  public static let cursorAnchor: CGFloat = 0.3

  /// Whether the columns keep a fixed width and the music scrolls.
  public let scrolls: Bool

  /// How full a last system must be before it is justified anyway.
  ///
  /// A last line that is nearly full looks worse with a small gap than filled,
  /// so editors stretch it; a short one is left short. The same judgement every
  /// engraving program makes.
  public static let lastSystemFillThreshold: CGFloat = 0.7

  /// Whether the line is stretched to fill the width.
  ///
  /// Printed music justifies every system except the last, which keeps its
  /// natural width and leaves paper to the right. Justifying the last one too
  /// is what makes four final notes sprawl across the page.
  public let justifies: Bool

  /// Written duration of each column, when the music has rhythm.
  ///
  /// Empty for a reading drill, where nothing is written and every column is
  /// the same width.
  public let durations: [Duration]

  /// Creates a layout.
  /// - Parameters:
  ///   - staffSpace: Distance between two staff lines, in points.
  ///   - width: Full width available.
  ///   - columnCount: How many columns of notes are drawn.
  ///   - preamble: Room reserved for the key and time signatures.
  ///   - scrolls: Whether columns keep a fixed width and the music scrolls.
  ///   - durations: Written duration per column, or empty for equal columns.
  ///   - justifies: Whether the line is stretched to fill the width.
  public init(
    staffSpace: CGFloat,
    width: CGFloat,
    columnCount: Int,
    preamble: CGFloat = 0,
    scrolls: Bool = false,
    durations: [Duration] = [],
    justifies: Bool = false
  ) {
    self.staffSpace = staffSpace
    self.width = width
    self.columnCount = max(columnCount, 0)
    self.preamble = max(preamble, 0)
    self.scrolls = scrolls
    self.durations = durations
    self.justifies = justifies
  }

  /// How wide one column is.
  ///
  /// Proportional to the written duration, not compressed the way engraving
  /// compresses it for page economy. There is no page to economise here, and
  /// there is a guide line moving at a constant speed: with space proportional
  /// to time, the line and the notes move on the same scale, so following the
  /// music is one thing to do rather than two. The eye also starts reading
  /// duration as distance, before it reads the figure.
  /// - Parameter column: Which column, counting from zero.
  /// - Returns: Its width in points.
  public func width(ofColumn column: Int) -> CGFloat {
    naturalWidth(ofColumn: column) * justificationScale
  }

  /// How wide a column wants to be before the line is stretched.
  private func naturalWidth(ofColumn column: Int) -> CGFloat {
    guard durations.indices.contains(column) else { return spacing }
    return proportionalBase * CGFloat(durations[column].beats)
  }

  /// Points per crotchet, chosen so the shortest figure present is legible.
  ///
  /// A floor applied per column would guarantee legibility and destroy the
  /// proportions doing it: a quaver clamped up to the floor stops being half a
  /// crotchet, and the spacing stops telling the truth about time. Scaling
  /// everything from the shortest figure keeps the ratios exact and still
  /// leaves the smallest note room to be drawn.
  private var proportionalBase: CGFloat {
    let shortest = durations.map { CGFloat($0.beats) }.min() ?? 1
    let smallestReadable = Self.minimumSpacing * staffSpace * 0.6

    return max(Self.minimumSpacing * staffSpace, smallestReadable / max(shortest, 0.01))
  }

  /// How much the line is stretched so it fills the width.
  ///
  /// Applied to every column equally, so stretching a system never changes
  /// which note looks longer than which — the proportions are the reading.
  private var justificationScale: CGFloat {
    guard justifies, columnCount > 0 else { return 1 }

    let natural = (0..<columnCount).reduce(0) { $0 + naturalWidth(ofColumn: $1) }
    guard natural > 0, natural < noteAreaWidth else { return 1 }

    return noteAreaWidth / natural
  }

  /// Left edge of a column, measured from the start of the note area.
  /// - Parameter column: Which column, counting from zero.
  /// - Returns: Its left edge, in points from the note area start.
  public func start(ofColumn column: Int) -> CGFloat {
    let capped = min(max(column, 0), columnCount)
    guard capped > 0 else { return 0 }
    return (0..<capped).reduce(0) { $0 + width(ofColumn: $1) }
  }

  /// Where the clef is drawn.
  public var clefX: CGFloat { staffSpace * 0.6 }

  /// Where the key and time signatures begin, just past the clef.
  public var preambleStart: CGFloat { clefX + staffSpace * 3.2 }

  /// Left edge of the note area, past the clef and the signatures.
  public var noteAreaStart: CGFloat { clefX + staffSpace * 4 + preamble }

  /// Width available to the notes.
  public var noteAreaWidth: CGFloat {
    max(width - noteAreaStart - staffSpace * 2, staffSpace)
  }

  /// Horizontal distance between two columns.
  ///
  /// When the staff scrolls this is fixed, so the music stays legible however
  /// long it is. Otherwise the columns share the width, which is right for a
  /// short generated drill that always fits.
  public var spacing: CGFloat {
    guard columnCount > 0 else { return 0 }
    guard scrolls else { return noteAreaWidth / CGFloat(columnCount) }
    return max(Self.minimumSpacing * staffSpace, noteAreaWidth / CGFloat(columnCount))
  }

  /// Where the staff lines should stop.
  ///
  /// On a justified system, the margin. On a short last system, the end of the
  /// music: staff lines running past the final bar line into empty space are
  /// not something printed music does.
  public var staffLineEnd: CGFloat {
    guard !justifies, !durations.isEmpty else { return width }
    return min(noteAreaStart + contentWidth + staffSpace, width)
  }

  /// Whether a last system this full should be justified regardless.
  /// - Parameters:
  ///   - naturalWidth: How wide the music on that line wants to be.
  ///   - available: The width of a line.
  /// - Returns: Whether to stretch it.
  public static func justifiesLastSystem(
    naturalWidth: CGFloat,
    available: CGFloat
  ) -> Bool {
    guard available > 0 else { return false }
    return naturalWidth / available > lastSystemFillThreshold
  }

  /// How wide the music is, which may be far wider than the view.
  public var contentWidth: CGFloat {
    // Written rhythm decides the width whenever there is any; only a drill with
    // no figures falls back to dividing the line equally.
    guard !durations.isEmpty else { return spacing * CGFloat(columnCount) }
    return start(ofColumn: columnCount)
  }

  /// How far the music is shifted left so a column sits at the cursor anchor.
  ///
  /// Clamped at both ends: never before the first note, and never so far that
  /// the music pulls away from the right edge once the end is in view.
  /// - Parameter column: The column to bring to the anchor.
  /// - Returns: How much to shift the music left, never negative.
  public func offset(focusing column: Int) -> CGFloat {
    guard scrolls, columnCount > 0 else { return 0 }

    let anchor = noteAreaWidth * Self.cursorAnchor
    let capped = min(max(column, 0), columnCount)
    let centre = start(ofColumn: capped) + width(ofColumn: capped) / 2
    let furthest = max(contentWidth - noteAreaWidth, 0)

    return min(max(centre - anchor, 0), furthest)
  }

  /// Centre of one column.
  /// - Parameter column: Which column, counting from zero.
  /// - Returns: Its centre, in points from the left edge.
  public func x(ofColumn column: Int) -> CGFloat {
    noteAreaStart + start(ofColumn: column) + width(ofColumn: column) / 2
  }

  /// How far the music is shifted left for a focus between two columns.
  ///
  /// Taking a fraction rather than an index is what lets the scroll glide: an
  /// integer can only jump, and a jumping stave is the opposite of following.
  /// - Parameter position: The focus, in columns, possibly fractional.
  /// - Returns: How much to shift the music left, never negative.
  public func offset(focusing position: Double) -> CGFloat {
    guard scrolls, columnCount > 0 else { return 0 }

    let whole = Int(position.rounded(.down))
    let fraction = CGFloat(position - Double(whole))
    let here = offset(focusing: whole)
    let next = offset(focusing: whole + 1)

    return here + (next - here) * min(max(fraction, 0), 1)
  }

  /// Where a playhead sits when it is partway between two columns.
  ///
  /// Interpolating between column centres — rather than sweeping the whole
  /// width — is what keeps the line and the note heads in step.
  /// - Parameters:
  ///   - column: The column just reached.
  ///   - progress: How far towards the next one, from 0 to 1.
  /// - Returns: The playhead position, in points from the left edge.
  public func playheadX(column: Int, progress: Double) -> CGFloat {
    guard columnCount > 0 else { return noteAreaStart }

    let clampedColumn = min(max(column, 0), columnCount)
    let clampedProgress = min(max(progress, 0), 1)
    let position =
      x(ofColumn: clampedColumn) + width(ofColumn: clampedColumn) * CGFloat(clampedProgress)

    // Clamping the column and the progress separately is not enough: together
    // they can still push the line past the end of the staff.
    return min(position, x(ofColumn: columnCount))
  }
}
