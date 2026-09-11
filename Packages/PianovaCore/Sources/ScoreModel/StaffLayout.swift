import CoreGraphics

/// Where the clef sits, given the staff size.
///
/// Free of `self` so the initialiser can use it while laying the columns out.
private func clefXFor(_ staffSpace: CGFloat) -> CGFloat { staffSpace * 0.6 }

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

    // Widths and their running totals are worked out once, here. They used to
    // be recomputed on demand: `start(ofColumn:)` summed every column before
    // it, and each width recomputed the justification by summing every column
    // again — O(n³) per layout pass. At 545 columns that is on the order of a
    // hundred million operations, every animation frame.
    let count = self.columnCount
    var natural: [CGFloat] = []
    natural.reserveCapacity(count)

    let noteArea = max(
      width - (clefXFor(staffSpace) + staffSpace * 4 + self.preamble) - staffSpace * 2,
      staffSpace)

    if durations.isEmpty {
      // No written rhythm: a drill, where the columns simply share the line.
      let even = count > 0 ? max(Self.minimumSpacing * staffSpace, noteArea / CGFloat(count)) : 0
      natural = Array(repeating: even, count: count)
    } else {
      let shortest = durations.map { CGFloat($0.beats) }.min() ?? 1
      let smallestReadable = Self.minimumSpacing * staffSpace * 0.6
      let base = max(Self.minimumSpacing * staffSpace, smallestReadable / max(shortest, 0.01))

      for index in 0..<count {
        let beats = durations.indices.contains(index) ? CGFloat(durations[index].beats) : 1
        natural.append(base * beats)
      }
    }

    let total = natural.reduce(0, +)
    let scale = justifies && total > 0 && total < noteArea ? noteArea / total : 1

    columnWidths = natural.map { $0 * scale }

    var running: [CGFloat] = [0]
    running.reserveCapacity(count + 1)
    for value in columnWidths { running.append((running.last ?? 0) + value) }
    columnStarts = running
  }

  /// Width of each column, worked out once.
  private let columnWidths: [CGFloat]

  /// Running total of ``columnWidths``, with a leading zero.
  private let columnStarts: [CGFloat]

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
    columnWidths.indices.contains(column) ? columnWidths[column] : spacing
  }

  /// Left edge of a column, measured from the start of the note area.
  /// - Parameter column: Which column, counting from zero.
  /// - Returns: Its left edge, in points from the note area start.
  public func start(ofColumn column: Int) -> CGFloat {
    let capped = min(max(column, 0), columnStarts.count - 1)
    return capped >= 0 ? columnStarts[capped] : 0
  }

  /// Where the clef is drawn.
  public var clefX: CGFloat { clefXFor(staffSpace) }

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
