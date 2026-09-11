import Engraving
import ScoreModel
import Sound
import SwiftUI

#if canImport(PencilKit)
import PencilKit
#endif

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
        // Opening a long piece takes a moment; the screen says so instead of
        // freezing. Progress plus the piece's name, so the wait reads as
        // intentional and not as a hang.
        VStack(spacing: 14) {
          ProgressView()
            .controlSize(.large)
          Text("Gravando a partitura…")
            .font(.system(size: 14, weight: .medium))
          Text(score.title)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
      } else {
        pages
          .frame(maxHeight: .infinity, alignment: .top)
          .transition(.opacity)
          // A re-engrave — zoom, entering study — keeps the old page in view
          // with a quiet word, never a blank screen.
          .overlay(alignment: .top) {
            if controller.isEngraving {
              HStack(spacing: 8) {
                ProgressView()
                  .controlSize(.small)
                Text("Regravando…")
                  .font(.system(size: 12, weight: .medium))
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(.regularMaterial, in: Capsule())
              .shadow(color: Theme.shadow(colorScheme), radius: 8, y: 2)
              .padding(.top, 10)
              .transition(.move(edge: .top).combined(with: .opacity))
            }
          }
      }
    }
    .animation(.easeInOut(duration: 0.25), value: controller.pages.first?.id)
    .animation(.easeInOut(duration: 0.2), value: controller.isEngraving)
    // Study never changes the page: same engraving, same scroll, nothing
    // jumps. What changes is what is judged and what is faded.
    .onChange(of: session.phase) { _, _ in applyStudy() }
    .onChange(of: session.range) { _, _ in refreshSelection() }
    .onChange(of: session.hands) { _, _ in applyStudy() }
    .onChange(of: session.loops) { _, _ in controller.loops = session.loopsNow }
    .onChange(of: showsFingering) { _, value in
      controller.showsTexts = value
      controller.renderInks()
    }
    .onChange(of: judgesPedal) { _, value in controller.judgesPedal = value }
    .onChange(of: scoreUnits) { _, _ in reload() }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !hub.isConnected {
        PianoKeyboardView { controller.play($0) }
      }
    }
    .onAppear {
      controller.onFinished = onFinished
      controller.loops = session.loopsNow
      controller.showsTexts = showsFingering
      controller.judgesPedal = judgesPedal
      reload()
      hub.setListener(owner: controller) { [controller] event in
        switch event {
        case .pressed(let pitch, _): controller.play(pitch)
        case .sustainPedal(let isDown): controller.setSustain(isDown)
        case .released: break
        }
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

  /// How many systems have to be on screen at once, fewer at bigger sizes.
  ///
  /// Two is the floor at rest: with one, reading ahead is impossible — the
  /// line is turned and only then discovered. A bigger score size is choosing
  /// size over look-ahead, so the floor gives way with it.
  private var systemsInView: CGFloat { max(1.1, 2.2 * CGFloat(scoreUnits) / 2100) }

  /// The score size in engraving units — the accessibility steps (rule 115).
  ///
  /// Global and remembered: every piece opens at the size last chosen.
  @AppStorage("pianova.scoreUnits") private var scoreUnits = 2100

  /// The magnifier: how far the pinch has zoomed in, 1 at rest (rule 115).
  ///
  /// A lens and nothing else — it scales what is on screen, annotations
  /// included, and never re-engraves. Kept per visit, not persisted.
  @State private var pinch: CGFloat = 1

  /// The pinch as it happens, shown by scaling until the finger lifts.
  @State private var liveZoom: CGFloat = 1

  /// Whether written fingering is drawn, remembered between sessions.
  @AppStorage("pianova.showsFingering") private var showsFingering = true

  /// Whether the written pedal is judged (rule 140), remembered like hands.
  @AppStorage("pianova.judgesPedal") private var judgesPedal = false

  /// The tool the pencil holds, remembered between sessions.
  @AppStorage("pianova.annotationTool") private var annotationTool = "pen"

  /// The player's pencil marks, one canvas per page.
  private let annotations = AnnotationStore()

  /// The bars marked on the page while a passage is being chosen.
  ///
  /// Held rather than computed per frame: it changes on taps, and recomputing
  /// it on every layout pass was a good part of what made the page slow.
  @State private var selectedMeasures: Set<String> = []

  /// Engraves the piece at the chosen score size.
  private func reload() {
    guard let engraver else { return }
    controller.pageUnits = scoreUnits
    controller.load(
      score, using: engraver,
      hands: session.phase == .studying ? session.hands : .both)
    refreshSelection()
    controller.renderInks()
  }

  /// Applies what study means now: what is judged, what is faded, what loops.
  private func applyStudy() {
    let studying = session.phase == .studying
    controller.loops = session.loopsNow
    controller.restrict(
      to: studying ? session.range : nil,
      hands: studying ? session.hands : .both)
    refreshSelection()
    controller.renderInks()
  }

  /// One page with everything it wears, split out to keep the compiler sane.
  private func pageRow(_ page: EngravedPage, index: Int, drawnWidth: CGFloat) -> some View {
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
      annotations: AnyView(
        annotationLayer(page: page, pageIndex: index, scale: drawnWidth / max(page.size.width, 1))
      ),
      studyMeasures: studyMeasures,
      width: drawnWidth
    )
    .overlay(alignment: .top) { systemAnchors(for: page) }
    .overlay(alignment: .topLeading) { selectionMarker(for: page, pageIndex: index) }
    .padding(.vertical, 18)
    .asPage(colorScheme)
    .id(index)
  }

  /// The pencil's drawing surface over one page.
  ///
  /// The pencil draws and the finger never does, so there is no mode: the
  /// layer is simply always there on the iPad, and absent where no pencil is.
  /// Strokes live at the score size they were made at (rule 131) and come
  /// back whenever that size does; stored in page units, they ride the
  /// magnifier with the page instead of being lost to it.
  @ViewBuilder
  private func annotationLayer(page: EngravedPage, pageIndex: Int, scale: CGFloat) -> some View {
    #if canImport(UIKit) && canImport(PencilKit)
    AnnotationLayer(
      saved: annotations.drawing(title: score.title, units: scoreUnits, page: pageIndex)
        .flatMap { data in
          (try? PKDrawing(data: data))?
            .transformed(using: CGAffineTransform(scaleX: scale, y: scale))
            .dataRepresentation()
        },
      tool: AnnotationTool(rawValue: annotationTool) ?? .pen,
      onChange: { data in
        guard scale > 0, let drawing = try? PKDrawing(data: data) else { return }
        let onPage = drawing.transformed(
          using: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
        annotations.save(
          drawing.strokes.isEmpty ? Data() : onPage.dataRepresentation(),
          title: score.title, units: scoreUnits, page: pageIndex)
      }
    )
    .id("\(score.title)|\(scoreUnits)|\(pageIndex)|\(Int(scale * 1000))")
    #endif
  }

  /// The bars kept sharp while studying; everything else is scrimmed.
  private var studyMeasures: Set<String> {
    guard session.phase == .studying else { return [] }
    return controller.measureIDs(in: session.range)
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
    // The magnifier draws the pages larger, really larger — laid out, not
    // stretched — and the second axis opens so the zoomed page can pan.
    let drawnWidth = pageWidth(viewport: viewport) * pinch

    return Group {
      ScrollView(pinch > 1.001 ? [.vertical, .horizontal] : .vertical) {
        LazyVStack(spacing: 20) {
          ForEach(Array(controller.pages.enumerated()), id: \.offset) { index, page in
            pageRow(page, index: index, drawnWidth: drawnWidth)
          }
        }
        .frame(minWidth: viewport.width)
        .padding(.horizontal, 8)
      }
      .onChange(of: controller.focus) { _, id in
        guard let id, let system = system(containing: id) else { return }

        // Only when the cursor leaves the system on screen. Inside it, the
        // reader's eye does the moving and the page stays put.
        guard system != shownSystem else { return }
        let previous = shownSystem
        shownSystem = system

        // A lazy page far off screen has no anchors yet: scrolling straight
        // to a system there is silence — which is why the loop played on
        // while the page stayed behind. Jumping pages, glide to the page
        // row first (its id always exists), then settle on the system.
        let target = pageIndex(containingSystem: system)
        if let target, target != previous.flatMap(pageIndex(containingSystem:)) {
          withAnimation(.easeInOut(duration: 0.45)) {
            scroller.scrollTo(target, anchor: .top)
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.25)) {
              scroller.scrollTo(system, anchor: .top)
            }
          }
        } else {
          withAnimation(.easeInOut(duration: 0.45)) {
            scroller.scrollTo(system, anchor: .top)
          }
        }
      }
      // The pill floats over the scroll, not inside the page: pinned to the
      // paper it was clipped by the paper's own edges — a selection on the
      // last line hid its own confirmation. Out here it can also be clamped
      // to the screen, which is what the edit menu does.
      .overlayPreferenceValue(SelectionRectKey.self) { anchor in
        GeometryReader { proxy in
          if let anchor, session.phase == .selecting, !adjusting,
            let range = session.range
          {
            let rect = proxy[anchor]
            let above = rect.minY - 32
            let x = min(max(rect.midX, 96), proxy.size.width - 96)
            let y = above > 40 ? above : min(rect.maxY + 38, proxy.size.height - 40)

            studyPill(for: range)
              .position(x: x, y: max(y, 40))
          }
        }
      }
      // The pinch is a lens and nothing else (rule 115): it scales while it
      // lasts, and letting go keeps the magnification — no re-engrave, no
      // reflow, nothing moves or is lost.
      .scaleEffect(liveZoom, anchor: .top)
      .simultaneousGesture(
        MagnificationGesture()
          .onChanged { liveZoom = $0 }
          .onEnded { value in
            pinch = min(max(pinch * value, 1.0), 3.0)
            liveZoom = 1
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

    adjusting = !ended
    guard resized != range else { return }
    Haptics.selected()
    session.resize(resized)
  }

  /// The frame for one selection handle on one page, while selecting.
  private func handleFrame(end: KeyPath<PracticeRange, Int>, pageIndex: Int) -> CGRect? {
    guard session.phase == .selecting, let range = session.range else { return nil }
    return controller.frameOfBar(range[keyPath: end], pageIndex: pageIndex)
  }

  /// Publishes where the selection sits on screen, for the pill to follow.
  @ViewBuilder
  private func selectionMarker(for page: EngravedPage, pageIndex: Int) -> some View {
    if session.phase == .selecting, let range = session.range,
      let union = unionFrame(of: range, pageIndex: pageIndex)
    {
      GeometryReader { proxy in
        let scale = proxy.size.width / max(page.size.width, 1)

        // Placed with position, not offset: an offset moves a view when it is
        // drawn and not when it is laid out, and an anchor is layout — with
        // offset the pill's anchor sat at the top of the page, wherever the
        // selection actually was.
        Color.clear
          .frame(width: union.width * scale, height: union.height * scale)
          .position(x: union.midX * scale, y: union.midY * scale)
          .anchorPreference(key: SelectionRectKey.self, value: .bounds) { $0 }
      }
      .allowsHitTesting(false)
    }
  }

  /// The floating confirmation, hovering by the selection as an edit menu
  /// does.
  private func studyPill(for range: PracticeRange) -> some View {
    Button {
      Haptics.confirmed()
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

  /// Whether a finger is mid-adjustment, when the pill steps aside.
  @State private var adjusting = false

  /// A hold in progress: selection is born under the finger and follows it.
  ///
  /// The first report begins the selection right there, still pressed — the
  /// way holding text selects the word before anything lifts. Every movement
  /// after stretches the passage to the bar under the finger.
  private func holdDrag(at point: CGPoint, ended: Bool, pageIndex: Int) {
    defer {
      if ended {
        holdAnchor = nil
        adjusting = false
      }
    }

    guard let bar = controller.bar(atPagePoint: point, pageIndex: pageIndex) else { return }

    guard let anchor = holdAnchor else {
      holdAnchor = bar
      Haptics.selected()
      withAnimation(.easeOut(duration: 0.22)) { session.begin(at: bar) }
      return
    }

    adjusting = true
    let stretched = PracticeRange(first: anchor, last: bar)
    guard stretched != session.range else { return }
    Haptics.selected()
    session.resize(stretched)
  }

  /// Which system a note was drawn in, across every page.
  private func system(containing id: String) -> String? {
    controller.pages.compactMap { $0.system(containing: id) }.first
  }

  /// Which page row holds a system, for scrolling to pages the lazy list
  /// has not built yet.
  private func pageIndex(containingSystem id: String) -> Int? {
    controller.pages.firstIndex { page in page.systems.contains { $0.id == id } }
  }
}

/// Where the selection sits on screen, published by whichever page holds it.
private struct SelectionRectKey: PreferenceKey {
  static let defaultValue: Anchor<CGRect>? = nil

  static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
    value = nextValue() ?? value
  }
}
