import ScoreModel
import SwiftUI

/// A whole piece, laid out as printed music is: systems stacked down the page.
///
/// The single sideways-scrolling strip it replaces was unreadable the moment a
/// piece had a few hundred notes, and it is not how anyone reads music. Here
/// the eye does what reading actually is — left to right, then down — and the
/// page can be scrolled by hand as well as following the cursor.
struct ScoreSheetView: View {
  let score: Score
  let states: [ItemState]
  let focusColumn: Int
  let staffSpace: CGFloat

  /// Where the moving guide line is, or `nil` when nothing is playing.
  var playhead: PlayheadPosition? = nil

  /// Called with the first column of a system the player tapped.
  ///
  /// Studying is repeating a passage. Being able to say "from here" is what
  /// turns a preview into something usable more than once.
  var onPickStart: ((Int) -> Void)? = nil

  /// Vertical room between systems.
  private let systemGap: CGFloat = 18

  var body: some View {
    GeometryReader { proxy in
      let systems = Self.systems(of: score, staffSpace: staffSpace, width: proxy.size.width)

      ScrollViewReader { scroller in
        ScrollView(.vertical) {
          LazyVStack(alignment: .leading, spacing: systemGap) {
            ForEach(Array(systems.enumerated()), id: \.offset) { index, range in
              system(
                range, isLast: index == systems.count - 1,
                lineWidth: proxy.size.width
              )
              .id(index)
              .contentShape(Rectangle())
              .onTapGesture { onPickStart?(range.lowerBound) }
            }
          }
          .padding(.vertical, 4)
        }
        // Follows the cursor without taking the scroll away: dragging still
        // works, and looking ahead is part of reading.
        .onChange(of: focusColumn) { _, column in
          guard let index = systems.firstIndex(where: { $0.contains(column) }) else { return }
          withAnimation(.easeOut(duration: 0.35)) {
            scroller.scrollTo(index, anchor: .center)
          }
        }
      }
    }
  }

  /// One system: the slice of the piece that fits a line.
  ///
  /// Clef and key are repeated on every system, as printed music does; the time
  /// signature appears only on the first.
  @ViewBuilder
  private func system(_ range: Range<Int>, isLast: Bool, lineWidth: CGFloat) -> some View {
    let columns = Array(score.columns[range])
    let groups = columns.map(\.pitches)
    let durations = columns.map(\.duration)
    let slice = Array(states[safe: range])
    let bars = Set(
      score.barlineColumns.compactMap {
        $0 >= range.lowerBound && $0 < range.upperBound - 1 ? $0 - range.lowerBound : nil
      })

    let number = score.measureNumber(atColumn: range.lowerBound)

    // Beams are given in this system's own columns, like the guide line: a
    // system draws itself and knows nothing about its neighbours.
    let beams = score.beamGroups.compactMap { group -> Range<Int>? in
      guard group.lowerBound >= range.lowerBound, group.upperBound <= range.upperBound
      else { return nil }
      return (group.lowerBound - range.lowerBound)..<(group.upperBound - range.lowerBound)
    }

    // The last line is left short — unless it is nearly full, when a small gap
    // reads worse than a filled line. Same judgement editors make.
    let natural = StaffLayout(
      staffSpace: staffSpace, width: 10_000, columnCount: columns.count,
      durations: durations)
    let stretches =
      !isLast
      || StaffLayout.justifiesLastSystem(
        naturalWidth: natural.contentWidth, available: lineWidth)

    if score.isTwoHanded {
      GrandStaffView(
        upperGroups: columns.map(\.upper), lowerGroups: columns.map(\.lower),
        states: slice, staffSpace: staffSpace,
        durations: durations,
        timeSignature: range.lowerBound == 0 ? score.timeSignature : nil,
        key: score.key, barlinesAfter: bars, beamGroups: beams,
        showsFinalBarline: isLast,
        measureNumber: number, playhead: playhead?.within(range),
        justifies: stretches)
    } else {
      StaffView(
        clef: score.clef, noteGroups: groups, states: slice, durations: durations,
        staffSpace: staffSpace,
        timeSignature: range.lowerBound == 0 ? score.timeSignature : nil,
        key: score.key, barlinesAfter: bars, beamGroups: beams,
        showsFinalBarline: isLast,
        measureNumber: number, playhead: playhead?.within(range),
        justifies: stretches)
    }
  }

  /// How the piece divides into systems at a given width.
  static func systems(of score: Score, staffSpace: CGFloat, width: CGFloat) -> [Range<Int>] {
    let columns = score.columns
    guard !columns.isEmpty else { return [] }

    // Measured with the same layout the staff draws with, so what is planned
    // here and what is drawn there cannot disagree.
    let layout = StaffLayout(
      staffSpace: staffSpace, width: width, columnCount: columns.count,
      scrolls: true, durations: columns.map(\.duration))

    let preamble = layout.noteAreaStart + staffSpace * 4
    return SystemLayout.systems(
      widths: (0..<columns.count).map { layout.width(ofColumn: $0) },
      barlinesAfter: score.barlineColumns,
      available: max(width - preamble, staffSpace))
  }
}

extension Array {
  /// The slice at a range, clamped to what actually exists.
  ///
  /// State arrays and column arrays are built separately, and a piece that
  /// disagreed with itself by one would otherwise crash the whole screen.
  subscript(safe range: Range<Int>) -> ArraySlice<Element> {
    let low = Swift.max(range.lowerBound, 0)
    let high = Swift.min(range.upperBound, count)
    guard low < high else { return [] }
    return self[low..<high]
  }
}
