import CoreText
import Course
import ScoreModel
import SwiftUI

/// The figures a teaching page can show.
///
/// A method book is an illustrated book, and not for decoration: keyboard,
/// hands and duration are *spatial*. Saying in words where the C sits costs a
/// paragraph and still reads as ambiguous; a drawn keyboard with the key shaded
/// needs no sentence at all.
struct IllustrationView: View {
  let illustration: Illustration

  var body: some View {
    switch illustration {
    case .staff(let example):
      StaffExampleView(example: example)
    case .keyboard(let diagram):
      KeyboardDiagramView(diagram: diagram)
    case .hands(let diagram):
      HandDiagramView(diagram: diagram)
    case .valueTree(let tree):
      ValueTreeView(tree: tree)
    }
  }
}

/// A caption under a figure, in the one place that decides how they look.
private struct Caption: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// A passage of staff shown as an example.
struct StaffExampleView: View {
  let example: StaffExample

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      StaffView(
        clef: example.clef,
        noteGroups: example.pitches.map { [$0] },
        states: example.pitches.map { _ in .current },
        staffSpace: 16)

      Caption(text: example.caption)
    }
  }
}

// MARK: - Keyboard

/// A stretch of keyboard drawn as a diagram, with keys called out.
///
/// This is the picture a beginner needs most, and the one the app was missing:
/// the groups of two and three black keys are the map the hand navigates by,
/// and they are impossible to describe as quickly as they are to see.
struct KeyboardDiagramView: View {
  let diagram: KeyboardDiagram

  /// White key width, small enough that two octaves fit an iPad column.
  private let keyWidth: CGFloat = 26
  private let keyHeight: CGFloat = 96
  private let bracketHeight: CGFloat = 22

  private var layout: KeyboardLayout { KeyboardLayout(range: diagram.range) }
  private var blackWidth: CGFloat { keyWidth * KeyboardLayout.blackKeyWidthRatio }
  private var blackHeight: CGFloat { keyHeight * KeyboardLayout.blackKeyHeightRatio }
  private var width: CGFloat { CGFloat(layout.whiteKeys.count) * keyWidth }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ScrollView(.horizontal, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 4) {
          brackets
          ZStack(alignment: .topLeading) {
            whiteKeys
            blackKeys
          }
          .frame(width: width, height: keyHeight)
        }
        .padding(.horizontal, 1)
      }

      Caption(text: diagram.caption)
    }
  }

  /// The mark on a key, if it has one.
  private func mark(for pitch: Pitch) -> KeyMark? {
    diagram.marks.first { $0.pitch == pitch }
  }

  private func tint(_ mark: KeyMark?) -> Color {
    switch mark?.emphasis {
    case .primary: return .accentColor
    case .secondary: return .accentColor.opacity(0.28)
    case nil: return .clear
    }
  }

  // MARK: White keys

  private var whiteKeys: some View {
    HStack(spacing: 0) {
      ForEach(layout.whiteKeys, id: \.midiNoteNumber) { pitch in
        whiteKey(pitch)
      }
    }
  }

  private func whiteKey(_ pitch: Pitch) -> some View {
    let mark = mark(for: pitch)

    return ZStack(alignment: .bottom) {
      UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
        .fill(.white)
        .overlay(
          UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
            .fill(tint(mark))
        )
        .overlay(
          UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
            .strokeBorder(Color(white: 0.6), lineWidth: 0.5))

      if let label = mark?.label, !label.isEmpty {
        Text(label)
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .foregroundStyle(mark?.emphasis == .primary ? Color.white : Color(white: 0.25))
          .minimumScaleFactor(0.6)
          .lineLimit(1)
          .padding(.horizontal, 1)
          .padding(.bottom, 5)
      }
    }
    .frame(width: keyWidth, height: keyHeight)
  }

  // MARK: Black keys

  private var blackKeys: some View {
    ZStack(alignment: .topLeading) {
      ForEach(layout.blackKeys, id: \.midiNoteNumber) { pitch in
        if let centre = layout.blackKeyCentre(for: pitch) {
          blackKey(pitch)
            .offset(x: centre * keyWidth - blackWidth / 2)
        }
      }
    }
  }

  private func blackKey(_ pitch: Pitch) -> some View {
    let mark = mark(for: pitch)

    return ZStack(alignment: .bottom) {
      UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
        .fill(Color(white: 0.16))
        .overlay(
          UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
            .fill(tint(mark)))

      if let label = mark?.label, !label.isEmpty {
        Text(label)
          .font(.system(size: 8, weight: .semibold, design: .rounded))
          .foregroundStyle(.white)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
          .padding(.bottom, 4)
      }
    }
    .frame(width: blackWidth, height: blackHeight)
  }

  // MARK: Brackets

  /// Where a key sits horizontally, in points from the left edge.
  ///
  /// A black key is measured from its own leaning centre, so a bracket over the
  /// group of two really sits over those two keys and not beside them.
  private func x(of pitch: Pitch) -> CGFloat? {
    if pitch.requiresSharp {
      return layout.blackKeyCentre(for: pitch).map { $0 * keyWidth }
    }
    return layout.whiteKeyIndex(of: pitch).map { (CGFloat($0) + 0.5) * keyWidth }
  }

  private var brackets: some View {
    ZStack(alignment: .topLeading) {
      Color.clear.frame(width: width, height: bracketHeight)

      ForEach(Array(diagram.brackets.enumerated()), id: \.offset) { _, bracket in
        if let start = x(of: Pitch(bracket.range.lowerBound)),
          let end = x(of: Pitch(bracket.range.upperBound)),
          end > start
        {
          bracketShape(bracket.label, width: end - start)
            .offset(x: start)
        }
      }
    }
  }

  private func bracketShape(_ label: String, width span: CGFloat) -> some View {
    VStack(spacing: 1) {
      Text(label)
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
        .fixedSize()

      RoundedRectangle(cornerRadius: 1)
        .fill(Color.secondary.opacity(0.5))
        .frame(width: span, height: 2)
    }
    .frame(width: span, height: bracketHeight, alignment: .bottom)
  }
}

// MARK: - Hands

/// The hands with their fingers numbered.
///
/// Drawn as five pads per hand, fanned by finger length rather than as a
/// picture of a hand: what has to land is that the numbering is **mirrored**,
/// with both thumbs meeting in the middle. A realistic drawing would say that
/// less clearly, not more.
struct HandDiagramView: View {
  let diagram: HandDiagram

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .bottom, spacing: 28) {
        ForEach(diagram.hands, id: \.rawValue) { hand in
          handView(hand)
        }
      }

      Caption(text: diagram.caption)
    }
  }

  /// Fingers ordered as they appear left to right for this hand.
  ///
  /// The right hand reads 1 to 5 rightwards; the left hand is its mirror, so it
  /// reads 5 to 1. That reversal is the entire point of the figure.
  private func fingers(of hand: Hand) -> [Int] {
    hand == .right ? [1, 2, 3, 4, 5] : [5, 4, 3, 2, 1]
  }

  /// How far a finger stands up, in points.
  ///
  /// The middle finger is the longest, the thumb the shortest.
  private func height(ofFinger finger: Int) -> CGFloat {
    switch finger {
    case 1: return 26
    case 2: return 46
    case 3: return 52
    case 4: return 46
    default: return 34
    }
  }

  private func handView(_ hand: Hand) -> some View {
    VStack(spacing: 6) {
      HStack(alignment: .bottom, spacing: 4) {
        ForEach(fingers(of: hand), id: \.self) { finger in
          VStack(spacing: 3) {
            Capsule()
              .fill(finger == 1 ? Color.accentColor : Color.accentColor.opacity(0.35))
              .frame(width: 18, height: height(ofFinger: finger))

            Text("\(finger)")
              .font(.system(size: 11, weight: .bold, design: .rounded))
              .foregroundStyle(finger == 1 ? Color.accentColor : .primary)
          }
        }
      }

      Text(hand.name)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
  }
}

// MARK: - Value tree

/// The halving of note values, drawn as a tree.
///
/// One semibreve over two minims over four crotchets. The picture *is* the
/// rule, and it reads far quicker than the sentence that states it.
struct ValueTreeView: View {
  @Environment(\.colorScheme) private var colorScheme

  let tree: ValueTree

  /// SMuFL code points for the figures the tree can draw.
  private func glyph(for value: NoteValue) -> String {
    switch value {
    case .whole: return "\u{E1D2}"
    case .half: return "\u{E1D3}"
    case .quarter: return "\u{E1D5}"
    case .eighth: return "\u{E1D7}"
    case .sixteenth: return "\u{E1D9}"
    }
  }

  /// How many of this figure fill the longest row.
  private func count(of value: NoteValue) -> Int {
    guard let longest = tree.rows.first else { return 1 }
    return Int((longest.beats / value.beats).rounded())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(spacing: 6) {
        ForEach(tree.rows, id: \.rawValue) { value in
          row(value)
        }
      }
      .padding(12)
      .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

      Caption(text: tree.caption)
    }
  }

  private func row(_ value: NoteValue) -> some View {
    HStack(spacing: 3) {
      ForEach(0..<count(of: value), id: \.self) { _ in
        cell(value)
      }
    }
  }

  private func cell(_ value: NoteValue) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5)
        .fill(Color.accentColor.opacity(0.14))
        .overlay(
          RoundedRectangle(cornerRadius: 5)
            .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.5))

      FigureGlyph(glyph: glyph(for: value), colorScheme: colorScheme)
    }
    .frame(width: 54, height: 40)
  }
}

/// One music symbol, drawn in Bravura, centred in its box.
///
/// Small and unboxed, unlike the one the question rounds use: here the figure
/// is a cell of a tree, and the tree draws its own frame.
private struct FigureGlyph: View {
  let glyph: String
  let colorScheme: ColorScheme

  var body: some View {
    Canvas { context, size in
      let font = Bravura.font(staffSpace: 9)
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
        cgContext.textPosition = CGPoint(x: max((size.width - width) / 2, 0), y: 12)
        CTLineDraw(line, cgContext)
        cgContext.restoreGState()
      }
    }
  }
}
