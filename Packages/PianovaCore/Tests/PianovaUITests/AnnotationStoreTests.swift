import CoreGraphics
import Foundation
import Testing

@testable import PianovaUI

private func freshStore() -> AnnotationStore {
  AnnotationStore(
    folder: FileManager.default.temporaryDirectory
      .appendingPathComponent("annotations-\(UUID().uuidString)", isDirectory: true))
}

// MARK: - Rule 131: anotações ancoradas por compasso

/// Rule 131 — os traços de uma peça voltam ao reabrir, com compasso e âncora.
@Test func anchoredStrokesSurviveTheRoundTrip() {
  let store = freshStore()
  let strokes = [
    AnnotationStore.AnchoredStroke(
      bar: 12, anchor: CGRect(x: 100, y: 50, width: 300, height: 400),
      stroke: Data("risco".utf8)),
    AnnotationStore.AnchoredStroke(
      bar: 3, anchor: CGRect(x: 0, y: 0, width: 200, height: 380),
      stroke: Data("outro".utf8)),
  ]

  store.save(strokes, title: "Bach")

  #expect(store.strokes(title: "Bach") == strokes)
}

/// Rule 131 — peças diferentes não se misturam; a lista vazia limpa o disco.
@Test func piecesKeepTheirOwnStrokes() {
  let store = freshStore()
  let stroke = AnnotationStore.AnchoredStroke(
    bar: 1, anchor: CGRect(x: 0, y: 0, width: 10, height: 10), stroke: Data("a".utf8))

  store.save([stroke], title: "Bach")
  #expect(store.strokes(title: "Grieg").isEmpty)

  store.save([], title: "Bach")
  #expect(store.strokes(title: "Bach").isEmpty)
}

/// Limpar a peça leva os traços dela — e só dela.
@Test func clearingAPieceSparesTheOthers() {
  let store = freshStore()
  let stroke = AnnotationStore.AnchoredStroke(
    bar: 1, anchor: CGRect(x: 0, y: 0, width: 10, height: 10), stroke: Data("a".utf8))
  store.save([stroke], title: "Bach")
  store.save([stroke], title: "Grieg")

  store.clear(title: "Bach")

  #expect(store.strokes(title: "Bach").isEmpty)
  #expect(store.strokes(title: "Grieg") == [stroke])
}

// MARK: - Rule 131: a âncora re-projeta o traço na caixa nova do compasso

/// Rule 131 — o mapa da caixa velha para a nova leva canto em canto: o
/// círculo desenhado sobre o compasso acompanha o compasso, em qualquer zoom.
@Test func theAnchorTransformMapsOldFrameOntoNew() {
  let old = CGRect(x: 100, y: 200, width: 300, height: 400)
  let new = CGRect(x: 50, y: 900, width: 600, height: 800)

  let transform = AnnotationAnchor.transform(from: old, to: new)

  #expect(CGPoint(x: 100, y: 200).applying(transform) == CGPoint(x: 50, y: 900))
  #expect(CGPoint(x: 400, y: 600).applying(transform) == CGPoint(x: 650, y: 1700))
  // O centro segue no centro.
  #expect(CGPoint(x: 250, y: 400).applying(transform) == CGPoint(x: 350, y: 1300))
}

/// Rule 131 — caixa igual, transformação identidade: nada se mexe à toa.
@Test func anUnchangedFrameMovesNothing() {
  let frame = CGRect(x: 10, y: 20, width: 100, height: 200)
  #expect(AnnotationAnchor.transform(from: frame, to: frame) == .identity)
}

#if canImport(PencilKit)
  import PencilKit

  /// Rule 131 — o traço decomposto numa caixa e recomposto noutra aparece
  /// onde o compasso foi parar, no tamanho novo: o zoom não o perde.
  @Test func aStrokeFollowsItsBarAcrossReflow() throws {
    // Um traço horizontal em pontos de view, com a view na metade da página.
    let points = (0..<10).map { index in
      PKStrokePoint(
        location: CGPoint(x: 100 + index * 2, y: 100),
        timeOffset: Double(index) * 0.01,
        size: CGSize(width: 3, height: 3), opacity: 1, force: 1,
        azimuth: 0, altitude: .pi / 2)
    }
    let stroke = PKStroke(
      ink: PKInk(.pen, color: .black),
      path: PKStrokePath(controlPoints: points, creationDate: Date()))
    let drawn = PKDrawing(strokes: [stroke]).dataRepresentation()

    // Na página (escala 0,5) o traço vive em (200, 200), dentro da caixa
    // do compasso 5.
    let oldFrame = CGRect(x: 150, y: 150, width: 200, height: 200)
    let anchored = AnchoredAnnotations.decompose(drawn, scale: 0.5, barAt: { _ in (5, oldFrame) })
    #expect(anchored.count == 1)
    #expect(anchored.first?.bar == 5)

    // O zoom refluiu: o compasso 5 agora mora noutro lugar, no dobro do
    // tamanho. O traço tem que ir junto, proporcional.
    let newFrame = CGRect(x: 1000, y: 400, width: 400, height: 400)
    let composed = try #require(
      AnchoredAnnotations.compose(anchored, frameOfBar: { _ in newFrame }, scale: 1))
    let bounds = try #require(try PKDrawing(data: composed).strokes.first).renderBounds

    // (100,100) na view = (200,200) na página = 25% da caixa velha —
    // na nova: 1000 + 0,25×400 = 1100 e 400 + 0,25×400 = 500.
    #expect(abs(bounds.minX - 1100) < 10, Comment(rawValue: "x=\(bounds.minX)"))
    #expect(abs(bounds.minY - 500) < 10, Comment(rawValue: "y=\(bounds.minY)"))
  }
#endif
