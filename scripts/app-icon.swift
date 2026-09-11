import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Pianova app icon: a P whose stem is a real keyboard octave seen sideways.
// All geometry exact — groups of 2 and 3 black keys where a piano has them.

let size = 1024.0
guard
  let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("no context") }

func rgb(_ hex: UInt32) -> CGColor {
  CGColor(
    red: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Background: deep navy, faint vertical light from the top.
let bgTop = rgb(0x16_2A5E)
let bgBottom = rgb(0x0A_142F)
let gradient = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: [bgTop, bgBottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
  gradient, start: CGPoint(x: size / 2, y: size), end: CGPoint(x: size / 2, y: 0), options: [])

// ---- The P (drawn in flipped coords: y grows down for sanity) ----
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

let stem = CGRect(x: 305, y: 240, width: 170, height: 560)
let bowlCenter = CGPoint(x: 535, y: 425)
let bowlOuter = 185.0
let bowlInner = 92.0

// Silhouette: stem + outer bowl, unioned; the bowl's eye punched even-odd.
let silhouette = CGMutablePath()
silhouette.addRoundedRect(in: stem, cornerWidth: 30, cornerHeight: 30)
silhouette.addEllipse(
  in: CGRect(
    x: bowlCenter.x - bowlOuter, y: bowlCenter.y - bowlOuter,
    width: bowlOuter * 2, height: bowlOuter * 2))
ctx.addPath(silhouette)
ctx.setFillColor(rgb(0xF7_F9FE))
ctx.fillPath()

// The bowl's eye, shown as background again — clipped to the right of the
// stem, so the eye never bites into the keyboard.
ctx.saveGState()
ctx.addEllipse(
  in: CGRect(
    x: bowlCenter.x - bowlInner, y: bowlCenter.y - bowlInner,
    width: bowlInner * 2, height: bowlInner * 2))
ctx.clip()
ctx.clip(to: CGRect(x: stem.maxX, y: 0, width: size, height: size))
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)
ctx.drawLinearGradient(
  gradient, start: CGPoint(x: size / 2, y: size), end: CGPoint(x: size / 2, y: 0), options: [])
ctx.restoreGState()

// ---- The keyboard inside the stem ----
// Seven white keys top to bottom: C D E F G A B. Boundaries carry the black
// keys: 2 between C-D and D-E, 3 between F-G, G-A, A-B. Exact octave.
let keyCount = 7.0
let keyHeight = stem.height / keyCount
let blackColor = rgb(0x0D_1A3B)

// Black keys: at boundaries 1, 2 (group of two) and 4, 5, 6 (group of three),
// reaching from the left edge across ~58% of the stem, like keys seen from
// the side.
ctx.setFillColor(blackColor)
for boundary in [1, 2, 4, 5, 6] {
  let y = stem.minY + Double(boundary) * keyHeight
  let rect = CGRect(x: stem.minX, y: y - 27, width: stem.width * 0.58, height: 54)
  let path = CGPath(
    roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)
  ctx.addPath(path)
  ctx.fillPath()
}

// ---- Save ----
let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("ok")
