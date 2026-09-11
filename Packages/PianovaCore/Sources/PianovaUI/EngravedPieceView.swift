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

  /// What is being worked at, shared with the bars that show and change it.
  @ObservedObject var session: StudySession

  let onFinished: () -> Void

  /// Called when a note is tapped while browsing, with the column it sits on.
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
    .onChange(of: session.phase) { was, now in
      // Entering or leaving study is the one thing that changes the page:
      // study engraves the passage alone, everything else engraves the piece.
      if was == .studying || now == .studying { reload() }
    }
    .onChange(of: session.range) { _, _ in refreshSelection() }
    .onChange(of: session.hands) { _, hands in
      controller.restrict(to: nil, hands: hands)
      controller.renderInks()
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
      reload()
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

  /// How many systems have to be on screen at once, fewer when zoomed in.
  ///
  /// Two is the floor at rest: with one, reading ahead is impossible — the
  /// line is turned and only then discovered. Zooming in is choosing size
  /// over look-ahead, so the floor gives way with it.
  private var systemsInView: CGFloat { max(1.1, 2.2 / zoom) }

  /// How far in the page is, 1 being at rest.
  ///
  /// Applied by re-engraving at a narrower page, so the music reflows instead
  /// of stretching.
  @State private var zoom: CGFloat = 1

  /// The pinch as it happens, shown by scaling until the reflow lands.
  @State private var liveZoom: CGFloat = 1

  /// The bars marked on the page while a passage is being chosen.
  ///
  /// Held rather than computed per frame: it changes on taps, and recomputing
  /// it on every layout pass was a good part of what made the page slow.
  @State private var selectedMeasures: Set<String> = []

  /// What the engraver should be drawing right now.
  private var shown: Score {
    session.phase == .studying ? score.extracting(session.range) : score
  }

  /// Engraves what the phase asks for and re-applies the study to it.
  private func reload() {
    guard let engraver else { return }
    controller.pageUnits = Int(2100 / zoom)
    controller.load(shown, using: engraver)
    controller.restrict(to: nil, hands: session.phase == .studying ? session.hands : .both)
    refreshSelection()
    shownSystem = nil
    controller.renderInks()
  }

  /// Marks the anchor bar while choosing, and nothing otherwise.
  private func refreshSelection() {
    selectedMeasures =
      session.phase == .selecting ? controller.measureIDs(in: session.range) : []
  }

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
    let allowed = viewport.height / systemsInView
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
              masks: controller.inkMasks[controller.inkKey(for: page)],
              highlights: controller.highlights,
              onTap: { id in tapped(id) },
              onHoldDrag: { point, ended in
                holdDrag(at: point, ended: ended, pageIndex: index)
              },
              onTapAt: { point in tappedPoint(point, pageIndex: index) },
              selectedMeasures: selectedMeasures,
              leadingHandle: handleFrame(end: \.first, pageIndex: index),
              trailingHandle: handleFrame(end: \.last, pageIndex: index),
              onHandleDrag: { point, isLeading, ended in
                dragHandle(to: point, isLeading: isLeading, ended: ended, pageIndex: index)
              },
              quietStaff: controller.quietStaff,
              width: drawnWidth
            )
            .overlay(alignment: .top) { systemAnchors(for: page) }
            .overlay(alignment: .topLeading) { studyPill(for: page, pageIndex: index) }
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
      // The pinch shows itself by scaling while it lasts; letting go
      // re-engraves at the new size, so the page reflows — fewer bars per
      // line closer up, more further out — instead of stretching a picture.
      .scaleEffect(liveZoom, anchor: .top)
      .simultaneousGesture(
        MagnificationGesture()
          .onChanged { liveZoom = $0 }
          .onEnded { value in
            zoom = min(max(zoom * value, 0.7), 2.0)
            liveZoom = 1
            reload()
          }
      )
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

  /// A short tap on a note while browsing picks where to listen from.
  private func tapped(_ id: String) {
    guard session.phase == .browsing, let column = controller.column(of: id) else { return }
    onPickStart?(column)
  }

  /// A short tap while selecting speaks the tap grammar: inside confirms,
  /// beyond extends, and off the staves deselects — like tapping around text.
  private func tappedPoint(_ point: CGPoint, pageIndex: Int) {
    guard session.phase == .selecting else { return }

    let bar = controller.bar(exactlyAtPagePoint: point, pageIndex: pageIndex)
    let before = (session.phase, session.range)
    withAnimation(.easeOut(duration: 0.18)) { session.tap(bar) }
    if (session.phase, session.range) != before { Haptics.selected() }
  }

  /// Follows a handle drag: the bar under the finger becomes that end.
  private func dragHandle(to point: CGPoint, isLeading: Bool, ended: Bool, pageIndex: Int) {
    guard session.phase == .selecting, let range = session.range,
      let bar = controller.bar(atPagePoint: point, pageIndex: pageIndex)
    else { return }

    let resized =
      isLeading
      ? PracticeRange(first: bar, last: range.last)
      : PracticeRange(first: range.first, last: bar)

    guard resized != range else { return }
    Haptics.selected()
    withAnimation(.easeOut(duration: 0.12)) { session.resize(resized) }
  }

  /// The frame for one selection handle on one page, while selecting.
  private func handleFrame(end: KeyPath<PracticeRange, Int>, pageIndex: Int) -> CGRect? {
    guard session.phase == .selecting, let range = session.range else { return nil }
    return controller.frameOfBar(range[keyPath: end], pageIndex: pageIndex)
  }

  /// The floating confirmation, hovering by the selection as an edit menu
  /// does.
  @ViewBuilder
  private func studyPill(for page: EngravedPage, pageIndex: Int) -> some View {
    if session.phase == .selecting, let range = session.range,
      let union = unionFrame(of: range, pageIndex: pageIndex)
    {
      GeometryReader { proxy in
        let scale = proxy.size.width / max(page.size.width, 1)
        let above = union.minY * scale - 32
        let x = min(max(union.midX * scale, 96), proxy.size.width - 96)

        Button {
          withAnimation(.easeOut(duration: 0.22)) { session.commit() }
        } label: {
          HStack(spacing: 8) {
            Text("Estudar")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Theme.accent)
            Text(range.count == 1 ? "1 compasso" : "\(range.count) compassos")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 9)
          .background(.regularMaterial, in: Capsule())
          .shadow(color: Theme.shadow(colorScheme), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        // Above the selection, as the edit menu sits above text — below it
        // only when there is no room above.
        .position(x: x, y: above > 30 ? above : union.maxY * scale + 38)
      }
      .allowsHitTesting(true)
    }
  }

  /// Every selected bar's box on one page, joined.
  private func unionFrame(of range: PracticeRange, pageIndex: Int) -> CGRect? {
    let boxes = (range.first...range.last)
      .compactMap {
        controller.frameOfBar($0, pageIndex: pageIndex)
      }
    guard let first = boxes.first else { return nil }
    return boxes.dropFirst().reduce(first) { $0.union($1) }
  }

  /// The bar a hold began on, which the moving finger stretches from.
  @State private var holdAnchor: Int?

  /// A hold in progress: selection is born under the finger and follows it.
  ///
  /// The first report begins the selection right there, still pressed — the
  /// way holding text selects the word before anything lifts. Every movement
  /// after stretches the passage to the bar under the finger.
  private func holdDrag(at point: CGPoint, ended: Bool, pageIndex: Int) {
    defer { if ended { holdAnchor = nil } }

    if session.phase == .studying {
      // The page in study is the passage alone, so its bars count from one
      // and go back into the piece's numbering. The reload replaces the page
      // mid-gesture, so this hold begins the choice and does no dragging.
      guard holdAnchor == nil, let bar = controller.bar(atPagePoint: point, pageIndex: pageIndex)
      else { return }
      let held = bar + (session.range?.first ?? 1) - 1

      holdAnchor = held
      Haptics.selected()
      withAnimation(.easeOut(duration: 0.22)) { session.begin(at: held) }
      return
    }

    guard let bar = controller.bar(atPagePoint: point, pageIndex: pageIndex) else { return }

    guard let anchor = holdAnchor else {
      holdAnchor = bar
      Haptics.selected()
      withAnimation(.easeOut(duration: 0.22)) { session.begin(at: bar) }
      return
    }

    let stretched = PracticeRange(first: anchor, last: bar)
    guard stretched != session.range else { return }
    Haptics.selected()
    withAnimation(.easeOut(duration: 0.12)) { session.resize(stretched) }
  }

  /// Which system a note was drawn in, across every page.
  private func system(containing id: String) -> String? {
    controller.pages.compactMap { $0.system(containing: id) }.first
  }
}
