#if canImport(UIKit) && canImport(PencilKit)
import PencilKit
import SwiftUI
import UIKit

/// The tool the pencil is holding.
public enum AnnotationTool: String, CaseIterable {
  /// A fine red pen, the classic teacher's mark.
  case pen
  /// A wide translucent highlighter.
  case highlighter
  /// The eraser, stroke by stroke.
  case eraser

  /// The name shown in the menu.
  var title: String {
    switch self {
    case .pen: return "Caneta"
    case .highlighter: return "Marca-texto"
    case .eraser: return "Borracha"
    }
  }

  var symbol: String {
    switch self {
    case .pen: return "pencil.tip"
    case .highlighter: return "highlighter"
    case .eraser: return "eraser"
    }
  }

  fileprivate var pkTool: PKTool {
    switch self {
    case .pen:
      return PKInkingTool(.pen, color: .systemRed, width: 4)
    case .highlighter:
      return PKInkingTool(.marker, color: .systemYellow.withAlphaComponent(0.5), width: 18)
    case .eraser:
      return PKEraserTool(.vector)
    }
  }
}

/// A drawing surface over one engraved page.
///
/// The pencil draws, the finger never does — `pencilOnly` is the whole trick:
/// finger touches fall through to the page beneath, so scrolling, selecting
/// and playing stay exactly as they are, and no mode has to be entered.
struct AnnotationLayer: UIViewRepresentable {
  /// The saved drawing to show, if any.
  let saved: Data?

  /// The tool in hand.
  let tool: AnnotationTool

  /// Told whenever the drawing changes, with its new data.
  let onChange: (Data) -> Void

  func makeUIView(context: Context) -> PKCanvasView {
    let canvas = PKCanvasView()
    canvas.backgroundColor = .clear
    canvas.isOpaque = false
    canvas.drawingPolicy = .pencilOnly
    canvas.delegate = context.coordinator

    // The canvas is a scroll view underneath, and waking it with the pencil
    // panned its own content — the ink slid sideways with a flicker. An
    // overlay the size of the page has nowhere to scroll to.
    canvas.isScrollEnabled = false

    if let saved, let drawing = try? PKDrawing(data: saved) {
      canvas.drawing = drawing
    }

    return canvas
  }

  func updateUIView(_ canvas: PKCanvasView, context: Context) {
    canvas.tool = tool.pkTool
    context.coordinator.onChange = onChange
  }

  func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

  final class Coordinator: NSObject, PKCanvasViewDelegate {
    var onChange: (Data) -> Void

    init(onChange: @escaping (Data) -> Void) {
      self.onChange = onChange
    }

    func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
      onChange(canvas.drawing.dataRepresentation())
    }
  }
}
#endif
