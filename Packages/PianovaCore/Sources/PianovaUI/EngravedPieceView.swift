import Engraving
import ScoreModel
import Sound
import SwiftUI

/// A piece drawn by a real engraver and played on the instrument.
///
/// Same rules as everywhere else — the cursor marks what to play, right
/// advances, wrong steps back. What changed is only who drew the page.
struct EngravedPieceView: View {
  @Environment(\.scoreEngraver) private var engraver
  @EnvironmentObject private var preview: ScorePlayer
  @StateObject private var controller = EngravedPlayController()
  @ObservedObject var hub: MIDIHub
  @Environment(\.colorScheme) private var colorScheme

  let score: Score

  /// What is being worked at, shared with the bar that changes it.
  @ObservedObject var session: StudySession

  let onFinished: () -> Void

  /// Called when a note is tapped, with the column it sits on.
  var onPickStart: ((Int) -> Void)?

  var body: some View {
    Group {
      if let failure = controller.failure {
        Text(failure)
          .font(.system(size: 13))
          .foregroundStyle(ItemState.failed.color)
          .frame(maxWidth: .infinity, minHeight: 200)
      } else if controller.pages.isEmpty {
        Text("Gravando…")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 200)
      } else {
        pages
          .frame(maxHeight: .infinity, alignment: .top)
      }

    }
    .onChange(of: session.study) { _, study in
      controller.restrict(to: study.range, hands: study.hands)
    }
    .onChange(of: session.loops) { _, value in controller.loops = value }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !hub.isConnected {
        PianoKeyboardView { controller.play($0) }
      }
    }
    .onAppear {
      controller.onFinished = onFinished
      controller.loops = session.loops
      if let engraver {
        controller.load(score, using: engraver)
        // Engraving resets what is judged, so a selection made before the page
        // was ready — coming back to a piece, say — has to be applied again.
        controller.restrict(to: session.range, hands: session.hands)
      }
      hub.setListener(owner: controller) { [controller] event in
        guard case .pressed(let pitch, _) = event else { return }
        controller.play(pitch)
      }
    }
    .onDisappear { hub.clearListener(owner: controller) }
    // While the piece plays itself the page follows the sound, not the cursor:
    // nobody is being judged, so there is nothing to point at.
    .onChange(of: preview.column) { _, column in
      guard preview.isPlaying else { return }
      controller.follow(column: column)
    }
    .onChange(of: preview.isPlaying) { _, isPlaying in
      if !isPlaying { controller.restoreCursor() }
    }
  }

  /// The system the page is currently showing.
  ///
  /// Held so the page only moves when the cursor leaves it. Scrolling on every
  /// note makes the page rise and fall with each change of hand.
  @State private var shownSystem: String?

  /// How many systems have to be on screen at once.
  ///
  /// Two is the floor: with one, reading ahead is impossible — the line is
  /// turned and only then discovered.
  private static let systemsInView: CGFloat = 2.2

  /// Every page, stacked, with the cursor kept in view.
  private var pages: some View {
    GeometryReader { outer in
      ScrollViewReader { scroller in
        scrollingPages(scroller, viewport: outer.size)
      }
    }
  }

  /// How wide to draw the page so enough of it fits on screen.
  ///
  /// Full width unless a system would then be taller than its share of the
  /// screen; beyond that the page is narrowed until two systems fit, because
  /// with one there is nothing to read ahead into.
  private func pageWidth(viewport: CGSize) -> CGFloat {
    guard let first = controller.pages.first, first.systemHeight > 0 else {
      return viewport.width
    }

    let atFullWidth = first.systemHeight / max(first.size.width, 1) * viewport.width
    let allowed = viewport.height / Self.systemsInView
    let shrink = min(1, allowed / max(atFullWidth, 1))

    return viewport.width * shrink
  }

  private func scrollingPages(
    _ scroller: ScrollViewProxy, viewport: CGSize
  ) -> some View {
    let drawnWidth = pageWidth(viewport: viewport)

    return Group {
      ScrollView(.vertical) {
        LazyVStack(spacing: 20) {
          ForEach(Array(controller.pages.enumerated()), id: \.offset) { index, page in
            EngravedScoreView(
              page: page,
              highlights: controller.highlights,
              onTap: { id in tapped(id) },
              onLongPress: { id in hold(id) },
              selectedMeasures: selectedMeasures(on: page),
              quietStaff: controller.quietStaff,
              width: drawnWidth
            )
            .overlay(alignment: .top) { systemAnchors(for: page) }
            .padding(.vertical, 18)
            .asPage(colorScheme)
            .id(index)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
      }
      .onChange(of: controller.focus) { _, id in
        guard let id, let system = system(containing: id) else { return }

        // Only when the cursor leaves the system on screen. Inside it, the
        // reader's eye does the moving and the page stays put.
        guard system != shownSystem else { return }
        shownSystem = system

        withAnimation(.easeInOut(duration: 0.45)) {
          scroller.scrollTo(system, anchor: .top)
        }
      }
    }
  }

  /// An invisible marker at the top of each system, to scroll to.
  ///
  /// Laid out with real spacers rather than positioned with `offset`: an offset
  /// moves a view when it is drawn and not when it is laid out, and
  /// `scrollTo` works on layout. Every anchor sat at the top of the page, so
  /// scrolling to any system went nowhere.
  private func systemAnchors(for engraved: EngravedPage) -> some View {
    GeometryReader { proxy in
      let scale = proxy.size.height / max(engraved.size.height, 1)

      VStack(spacing: 0) {
        ForEach(Array(engraved.systems.enumerated()), id: \.element.id) { index, system in
          let previous = index == 0 ? 0 : engraved.systems[index - 1].frame.minY
          let gap = max((system.frame.minY - previous) * scale - 1, 0)

          Color.clear.frame(height: index == 0 ? max(gap - 24, 0) : gap)
          Color.clear.frame(height: 1).id(system.id)
        }
        Spacer(minLength: 0)
      }
    }
    .allowsHitTesting(false)
  }

  /// Which bars are drawn as selected: the whole passage, not just the last tap.
  private func selectedMeasures(on page: EngravedPage) -> Set<String> {
    guard let range = session.range else { return [] }

    return Set(
      page.shapes.compactMap { shape -> String? in
        guard let measure = shape.measureID, let note = shape.noteID,
          let column = controller.column(of: note)
        else { return nil }

        let bar = score.measureNumber(atColumn: column)
        return range.judges(bar: bar) ? measure : nil
      })
  }

  /// A short tap: choose where to listen from, or extend a selection already
  /// under way.
  ///
  /// The same division Photos makes. Outside selection a tap means "here";
  /// inside it, it means "as far as here" — never "this one as well", because a
  /// passage is the stretch between two bars and not a set of them.
  private func tapped(_ id: String) {
    guard let column = controller.column(of: id) else { return }

    guard session.isSelecting else {
      onPickStart?(column)
      return
    }

    withAnimation(.easeOut(duration: 0.22)) {
      session.extend(to: score.measureNumber(atColumn: column))
    }
  }

  /// A long press: enter selection at this bar, as holding a photo does.
  private func hold(_ id: String) {
    guard let column = controller.column(of: id) else { return }

    Haptics.selected()
    withAnimation(.easeOut(duration: 0.22)) {
      session.begin(at: score.measureNumber(atColumn: column))
    }
  }

  /// Which system a note was drawn in, across every page.
  private func system(containing id: String) -> String? {
    controller.pages.compactMap { $0.system(containing: id) }.first
  }
}
