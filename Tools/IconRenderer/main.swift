import SwiftUI
import UIKit

// The app icon, drawn from the app's own code.
//
// This compiles against Theme, WoodGrain, KeyboardLayout and PianoNote rather
// than keeping its own copies of the palette or the geometry, so the icon
// cannot drift away from the instrument it stands for. Repaint it with
// Tools/IconRenderer/render.sh.
//
// The keyboard is laid out by KeyboardLayout.frames, which is the turned
// arrangement, and then transposed: pitch runs across instead of down and the
// struck end of each key faces the bottom of the icon. That reuse is the
// point. The black-key offsets, the thickness ratio and how far accidentals
// reach are all the real ones rather than a second set drawn by eye.

let side: CGFloat = 1024

/// What sits in the case above the keyboard.
///
/// The app has exactly one piece of brass and it is the range slider, so that
/// is what the icon borrows. Turned on its side: the light runs across the
/// short way, which is what makes a cylinder of it rather than a stripe.
enum Ornament {
    case none
    /// A bar of brass, its length a fraction of the icon's side.
    case bar(length: CGFloat)
}

struct Variant {
    /// White keys across the icon.
    let whiteKeys: Double
    /// Which white key the keyboard starts on, as a MIDI note.
    let startNote: Int
    /// Insets as fractions of the side, before the corner mask. `side` is used
    /// for the left and right margins, and matching `bottom` to it is what
    /// makes the band of wood round the keyboard an even width.
    let side: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    let ornament: Ornament
    /// How much to lift the brass out of the app's palette, as a multiplier on
    /// its saturation and brightness. One leaves it exactly as the app wears
    /// it, which is tarnished on purpose: on screen it sits on dark walnut at
    /// arm's length. The icon sits at sixty points on somebody else's
    /// wallpaper, and needs more.
    let brassLift: CGFloat
    /// A bright line along the top of the bar, where a turned edge would
    /// catch the light.
    let brassSpecular: Bool
    /// How much to lift the walnut, as a multiplier on its brightness. One is
    /// the case exactly as the app wears it. The icon competes with whatever
    /// wallpaper is behind it, where the app's own case only ever has to sit
    /// under your hands in a lit room.
    let caseLift: CGFloat
    /// How far the back corners of the keybed are rounded, as a fraction of the
    /// side. Zero is square.
    ///
    /// These are the one pair of corners here the mask has no say over, since
    /// no edge of the icon is near them.
    let keybedTop: CGFloat
    /// The top of the band the brass is centred in, as a fraction of the side.
    /// Zero centres the brass between the keyboard and the top edge of the
    /// image. A larger value centres it in the case you can actually see,
    /// which sits lower, because the top of the case runs away under the
    /// corner mask.
    let ornamentTop: CGFloat
}

// A full octave, pushed down the case, with the brass centred between the
// keyboard and the top edge. Earlier attempts, including fewer and larger keys
// and the slider drawn as a thumb in a routed channel, are in this file's
// history rather than kept here as dead options.
//
// The margins are not free: the corner mask eats anything sitting too close to
// an edge, and how close is too close depends on the mask's own curve, which
// is measured further down rather than guessed.
//
// The window has to end on a white key with no accidental above it, or the
// last black key is sliced in half by the edge of the keyboard. A full octave
// from C does. Most other counts do not.
/// One inset for the sides and the bottom, so the band of wood round the
/// keyboard is the same width on all three visible sides rather than nearly
/// the same. It is also what the bottom corners' radius is measured from, and
/// having one number feeding both is the point: change it and the margin and
/// the corner stay in agreement.
///
/// 0.072 is between the two the icon used before, which keeps the keys as
/// close to the size they were as an even margin allows, and it clears the
/// mask at every point.
let keyboardInset: CGFloat = 0.072

let icon = Variant(whiteKeys: 7, startNote: 60,
                   side: keyboardInset, top: 0.30, bottom: keyboardInset,
                   ornament: .bar(length: 0.52),
                   brassLift: 1.25, brassSpecular: true,
                   caseLift: 1.25,
                   keybedTop: 0,
                   ornamentTop: 0)

/// The icon mask, measured rather than assumed.
///
/// These two numbers describe the curve iOS masks an icon with, as a
/// superellipse: |x/r|^k + |y/r|^k = 1. They are fitted to the silhouette of a
/// solid-coloured icon lifted off a real home screen, and the fit is good to
/// under half a pixel on a 189 pixel icon.
///
/// Measuring them matters twice over. Guessing goes wrong quietly: an earlier
/// version used k = 5 and r = 0.224 on the reasoning that Apple's shape is a
/// squircle and a squircle has a high exponent, which made the icon read as
/// visibly squarer than its neighbours. And the shape is not fixed across
/// versions: iOS 18.3 measures 0.183 and 1.7, iOS 26 measures 0.309 and 2.6,
/// which is a great deal rounder. The keybed is cut as an offset of this
/// curve, so which version the numbers come from changes the drawing.
///
/// These are iOS 26, which is what the app ships to.
let maskCorner: CGFloat = 0.309
let cornerSquareness: CGFloat = 2.6

/// One quarter of the icon mask, sampled.
///
/// `ax` and `ay` say which way the quarter's two ends lie from its centre.
func maskCornerPoints(centre: CGPoint, radius: CGFloat,
                      ax: CGPoint, ay: CGPoint, steps: Int) -> [CGPoint] {
    (0...steps).map { step in
        let angle = CGFloat(step) / CGFloat(steps) * .pi / 2
        let u = pow(cos(angle), 2 / cornerSquareness)
        let v = pow(sin(angle), 2 / cornerSquareness)
        return CGPoint(x: centre.x + (ax.x * u + ay.x * v) * radius,
                       y: centre.y + (ax.y * u + ay.y * v) * radius)
    }
}

/// The keybed, as a path a fixed distance inside the icon's own mask.
///
/// Not a rounded rectangle. Two curves of the same radius but different
/// families diverge in the middle of a corner, and even two superellipses
/// sharing a centre do: the gap between them opens by about a quarter on the
/// diagonal. The only shape whose distance from the mask is the same
/// everywhere is the mask's own offset curve, so that is what this builds,
/// by walking the mask and stepping inwards along the normal at every point.
///
/// The cost is that the corner is no longer describable as a radius. The gain
/// is that the band of wood round the keyboard is the same width at the sides,
/// at the bottom, and through the corners, which is what the eye is actually
/// measuring.
func keybedPath(inset d: CGFloat, top: CGFloat, topRadius: CGFloat = 0) -> CGPath {
    let radius = side * maskCorner
    let steps = 256
    let path = CGMutablePath()

    /// Steps a sampled curve inwards along its own normal.
    func offset(_ points: [CGPoint], towards centre: CGPoint) -> [CGPoint] {
        points.enumerated().map { index, point in
            let before = points[max(0, index - 1)]
            let after = points[min(points.count - 1, index + 1)]
            var nx = -(after.y - before.y)
            var ny = after.x - before.x
            let length = max(sqrt(nx * nx + ny * ny), 0.000001)
            nx /= length
            ny /= length
            // Two normals at every point; take the one facing the centre.
            if (centre.x - point.x) * nx + (centre.y - point.y) * ny < 0 {
                nx = -nx
                ny = -ny
            }
            return CGPoint(x: point.x + nx * d, y: point.y + ny * d)
        }
    }

    let rightCentre = CGPoint(x: side - radius, y: side - radius)
    let leftCentre = CGPoint(x: radius, y: side - radius)

    // The back of the keybed, whose corners are the one thing here not set by
    // the mask: nothing of the icon's edge is near them.
    let t = topRadius
    path.move(to: CGPoint(x: d + t, y: top))
    path.addLine(to: CGPoint(x: side - d - t, y: top))
    if t > 0 {
        for point in maskCornerPoints(centre: CGPoint(x: side - d - t, y: top + t),
                                      radius: t,
                                      ax: CGPoint(x: 0, y: -1),
                                      ay: CGPoint(x: 1, y: 0), steps: 96) {
            path.addLine(to: point)
        }
    }
    path.addLine(to: CGPoint(x: side - d, y: side - radius))
    for point in offset(maskCornerPoints(centre: rightCentre, radius: radius,
                                         ax: CGPoint(x: 1, y: 0),
                                         ay: CGPoint(x: 0, y: 1), steps: steps),
                        towards: rightCentre) {
        path.addLine(to: point)
    }
    path.addLine(to: CGPoint(x: radius, y: side - d))
    for point in offset(maskCornerPoints(centre: leftCentre, radius: radius,
                                         ax: CGPoint(x: 0, y: 1),
                                         ay: CGPoint(x: -1, y: 0), steps: steps),
                        towards: leftCentre) {
        path.addLine(to: point)
    }
    if t > 0 {
        path.addLine(to: CGPoint(x: d, y: top + t))
        for point in maskCornerPoints(centre: CGPoint(x: d + t, y: top + t),
                                      radius: t,
                                      ax: CGPoint(x: -1, y: 0),
                                      ay: CGPoint(x: 0, y: -1), steps: 96) {
            path.addLine(to: point)
        }
    } else {
        path.addLine(to: CGPoint(x: d, y: top))
    }
    path.closeSubpath()
    return path
}

/// White keys first and accidentals after, which is also the drawing order.
func transposedFrames(_ v: Variant, keyboard: CGRect) -> [KeyFrame] {
    // The turned layout runs pitch down `span` and key length along `length`.
    let span = keyboard.width
    let length = keyboard.height
    let start = Double(KeyboardLayout.whitesBelow(PianoNote(midi: v.startNote)))
    let laid = KeyboardLayout.frames(position: start,
                                     visibleWhiteKeys: v.whiteKeys,
                                     in: CGRect(x: 0, y: 0, width: length, height: span))
    return laid.map { key in
        // Pitch becomes x. The struck end, which is x = 0 in the turned
        // layout, becomes the bottom edge, so accidentals reach down from the
        // top exactly as far as they reach in from the back.
        let f = key.frame
        return KeyFrame(note: key.note,
                        frame: CGRect(x: keyboard.minX + f.minY,
                                      y: keyboard.minY + (length - f.maxX),
                                      width: f.height,
                                      height: f.width))
    }
}

/// The case, built the way ContentView builds it: a warm gradient down the
/// board, faint banding across it, the grain over both, a sheen where the light
/// falls, and the outer edges darkened so the panel turns away at the sides.
func drawCase(_ cg: CGContext, _ v: Variant) {
    let full = CGRect(x: 0, y: 0, width: side, height: side)
    let space = CGColorSpaceCreateDeviceRGB()

    let wood = CGGradient(colorsSpace: space,
                          colors: [lifted(Theme.woodLight, by: v.caseLift),
                                   lifted(Theme.woodMid, by: v.caseLift),
                                   lifted(Theme.woodDark, by: v.caseLift)] as CFArray,
                          locations: [0, 0.5, 1])!
    cg.drawLinearGradient(wood,
                          start: CGPoint(x: 0, y: 0),
                          end: CGPoint(x: 0, y: side),
                          options: [])

    // The banding is a SwiftUI palette, so it is rebuilt here in the same order
    // and at the same opacities.
    let banding = Theme.woodGrain.map { UIColor($0).cgColor }
    let stops = (0..<banding.count).map { CGFloat($0) / CGFloat(banding.count - 1) }
    cg.saveGState()
    cg.setBlendMode(.overlay)
    cg.drawLinearGradient(CGGradient(colorsSpace: space,
                                     colors: banding as CFArray,
                                     locations: stops)!,
                          start: CGPoint(x: 0, y: 0),
                          end: CGPoint(x: side, y: 0),
                          options: [])
    cg.restoreGState()

    // Drawn at the size the case has on a phone and scaled up, so the figure
    // keeps the weight it has in the app instead of turning into stripes.
    WoodGrain.image(size: CGSize(width: 402, height: 402), scale: 2).draw(in: full)

    cg.saveGState()
    cg.setBlendMode(.softLight)
    let sheen = CGGradient(colorsSpace: space,
                           colors: [UIColor.white.withAlphaComponent(0.055).cgColor,
                                    UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                           locations: [0, 1])!
    cg.drawRadialGradient(sheen,
                          startCenter: CGPoint(x: side * 0.28, y: side * 0.10),
                          startRadius: side * 0.02,
                          endCenter: CGPoint(x: side * 0.28, y: side * 0.10),
                          endRadius: side * 1.1,
                          options: [])
    cg.restoreGState()

    let edges = CGGradient(colorsSpace: space,
                           colors: [UIColor.black.withAlphaComponent(0.30).cgColor,
                                    UIColor.black.withAlphaComponent(0).cgColor,
                                    UIColor.black.withAlphaComponent(0.36).cgColor] as CFArray,
                           locations: [0, 0.5, 1])!
    cg.drawLinearGradient(edges,
                          start: CGPoint(x: 0, y: 0),
                          end: CGPoint(x: side, y: 0),
                          options: [])
}

/// The brass, laid across the case above the keyboard.
///
/// Lit across its short axis and edged with the same brass line the catch and
/// the slider thumb both wear. Every colour is the app's own; none was invented
/// for the icon.
/// A colour from the app's palette, lifted for the icon.
///
/// Saturation and brightness both rise, because gold that is only brighter
/// goes pale rather than golden. Hue is left alone: the colour has to stay the
/// brass the app wears, or the icon stops matching the thing it opens.
func lifted(_ color: Color, by lift: CGFloat) -> CGColor {
    let ui = UIColor(color)
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    guard lift != 1 else { return ui.cgColor }
    return UIColor(hue: h,
                   saturation: min(1, s * (1 + (lift - 1) * 0.6)),
                   brightness: min(1, b * lift),
                   alpha: a).cgColor
}

func lifted(_ color: UIColor, by lift: CGFloat) -> CGColor {
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    guard lift != 1 else { return color.cgColor }
    return UIColor(hue: h,
                   saturation: min(1, s * (1 + (lift - 1) * 0.6)),
                   brightness: min(1, b * lift),
                   alpha: a).cgColor
}

func drawOrnament(_ cg: CGContext, _ v: Variant, above keyboard: CGRect) {
    guard case let .bar(length) = v.ornament else { return }

    let space = CGColorSpaceCreateDeviceRGB()
    let midY = (side * v.ornamentTop + keyboard.minY) / 2
    let height = side * (v.brassLift >= 1.5 ? 0.058 : 0.050)
    let rect = CGRect(x: (side - side * length) / 2, y: midY - height / 2,
                      width: side * length, height: height)
    let path = UIBezierPath(roundedRect: rect, cornerRadius: height / 2)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 6), blur: 12,
                 color: Theme.shadow.withAlphaComponent(0.5).cgColor)
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    cg.addPath(path.cgPath)
    cg.clip()
    let face = CGGradient(colorsSpace: space,
                          colors: [lifted(Theme.brassShadow, by: v.brassLift),
                                   lifted(Theme.brassHighlight, by: v.brassLift),
                                   lifted(Theme.brassMid, by: v.brassLift),
                                   lifted(Theme.brassShadow, by: v.brassLift)] as CFArray,
                          locations: [0, 0.30, 0.66, 1])!
    cg.drawLinearGradient(face,
                          start: CGPoint(x: rect.midX, y: rect.minY),
                          end: CGPoint(x: rect.midX, y: rect.maxY),
                          options: [])
    // The ends are cut faces, turned away from the light.
    let ends = CGGradient(colorsSpace: space,
                          colors: [UIColor.black.withAlphaComponent(0.35).cgColor,
                                   UIColor.black.withAlphaComponent(0).cgColor,
                                   UIColor.black.withAlphaComponent(0).cgColor,
                                   UIColor.black.withAlphaComponent(0.35).cgColor] as CFArray,
                          locations: [0, 0.09, 0.91, 1])!
    cg.drawLinearGradient(ends,
                          start: CGPoint(x: rect.minX, y: rect.midY),
                          end: CGPoint(x: rect.maxX, y: rect.midY),
                          options: [])
    cg.endTransparencyLayer()
    cg.restoreGState()

    if v.brassSpecular {
        // Where a turned edge would catch the light: inside the bar, along the
        // top, and stopped short of the ends so it reads as a highlight on a
        // curved face rather than as a second bar.
        let line = CGRect(x: rect.minX + rect.height * 0.9,
                          y: rect.minY + rect.height * 0.22,
                          width: rect.width - rect.height * 1.8,
                          height: max(1, rect.height * 0.10))
        cg.saveGState()
        cg.addPath(UIBezierPath(roundedRect: line,
                                cornerRadius: line.height / 2).cgPath)
        cg.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
        cg.fillPath()
        cg.restoreGState()
    }

    cg.saveGState()
    cg.addPath(path.cgPath)
    cg.setStrokeColor(lifted(Theme.capEdge, by: v.brassLift).copy(alpha: 0.46 * min(1.6, v.brassLift))!)
    cg.setLineWidth(height * 0.06)
    cg.strokePath()
    cg.restoreGState()
}

func draw(_ v: Variant) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    // The store rejects an icon with an alpha channel, and an opaque context
    // is how you avoid one rather than something to strip out afterwards.
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side),
                                           format: format)
    return renderer.image { context in
        let cg = context.cgContext
        drawCase(cg, v)

        // A negative bottom margin runs the keys off the edge of the image.
        let keyboard = CGRect(x: side * v.side,
                              y: side * v.top,
                              width: side * (1 - v.side * 2),
                              height: side * (1 - v.top - v.bottom))

        // The keybed the keys sit in, which shows as the seam between them. Its
        // corners are rounded a little more than the keys are clipped to, so a
        // hairline of keybed follows the curve and the keys do not run straight
        // into the wood.
        // The keybed sits a hairline outside where the keys are clipped, so a
        // line of it follows the curve and no key runs straight into the wood.
        let lip = side * 0.009
        let bed = keybedPath(inset: side * v.side - lip, top: keyboard.minY - lip,
                             topRadius: side * v.keybedTop + lip)
        cg.addPath(bed)
        cg.setFillColor(Theme.keybed.cgColor)
        cg.fillPath()
        // The bead of light along the top edge of the routed keybed.
        cg.setFillColor(Theme.caseHighlight.cgColor)
        cg.fill(CGRect(x: side * v.side - lip + side * v.keybedTop,
                       y: keyboard.minY - lip - 3,
                       width: side * (1 - v.side * 2) + lip * 2 - side * v.keybedTop * 2,
                       height: 3))

        drawOrnament(cg, v, above: keyboard)

        // Everything past the window belongs to the rest of the piano, which
        // the layout hands back along with the visible keys.
        cg.saveGState()
        cg.addPath(keybedPath(inset: side * v.side, top: keyboard.minY,
                              topRadius: side * v.keybedTop))
        cg.clip()

        let frames = transposedFrames(v, keyboard: keyboard)
            .filter { $0.frame.intersects(keyboard) }
        let stops = Theme.keyGradientStops.map { CGFloat(truncating: $0) }

        for key in frames {
            let colours = key.isBlack ? Theme.blackKey : Theme.whiteKey
            // Naturals are inset so the keybed shows through as the seam
            // between neighbours, the way the app insets them. In the app that
            // is one point against a key some fifty wide, so it is kept here as
            // a fraction rather than a count of pixels: a hairline scaled up to
            // a 1024 icon disappears, and the naturals then read as one cream
            // block at the size the icon is actually seen.
            let seam = key.isBlack ? 0 : key.frame.width * 0.022
            // A seam belongs between two keys. The outer edge of the first and
            // last key has no neighbour, and carrying one there put the cream
            // further in at the sides than at the bottom, which is visible as
            // an uneven band even though the keybed behind it is even.
            var body = key.frame.insetBy(dx: seam, dy: 0)
            if key.frame.minX - keyboard.minX < 1 {
                body = CGRect(x: keyboard.minX, y: body.minY,
                              width: body.maxX - keyboard.minX, height: body.height)
            }
            if keyboard.maxX - key.frame.maxX < 1 {
                body = CGRect(x: body.minX, y: body.minY,
                              width: keyboard.maxX - body.minX, height: body.height)
            }
            let keyRadius = key.isBlack ? body.width * 0.18 : body.width * 0.14
            // Only the front corners are rounded; the back of a key is square
            // against the keybed.
            let path = UIBezierPath(roundedRect: body,
                                    byRoundingCorners: [.bottomLeft, .bottomRight],
                                    cornerRadii: CGSize(width: keyRadius, height: keyRadius))
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: key.isBlack ? 14 : 5),
                         blur: key.isBlack ? 22 : 10,
                         color: Theme.shadow.withAlphaComponent(key.isBlack ? 0.5 : 0.3).cgColor)
            cg.beginTransparencyLayer(auxiliaryInfo: nil)
            cg.addPath(path.cgPath)
            cg.clip()
            // Front to back, which after transposing is bottom to top.
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colours as CFArray,
                                      locations: stops)!
            cg.drawLinearGradient(gradient,
                                  start: CGPoint(x: body.midX, y: body.maxY),
                                  end: CGPoint(x: body.midX, y: body.minY),
                                  options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            cg.endTransparencyLayer()
            cg.restoreGState()

            // The hairline along the lit front edge.
            let bevel = key.isBlack ? Theme.accidentalBevel : Theme.naturalBevel
            let inset = keyRadius * 0.7
            cg.setFillColor(bevel.cgColor)
            cg.fill(CGRect(x: body.minX + inset,
                           y: body.maxY - 5,
                           width: body.width - inset * 2,
                           height: 5))
        }
        cg.restoreGState()
    }
}

/// PNG data with no alpha channel at all.
///
/// An opaque renderer still writes RGBA, and the store refuses an icon with an
/// alpha channel. The one that shipped first had one and survived, because
/// Xcode flattens the asset catalog on the way into the app, but relying on
/// that is relying on a step that is not ours.
func flattenedPNG(_ image: UIImage) -> Data {
    let cg = image.cgImage!
    let context = CGContext(data: nil,
                            width: cg.width, height: cg.height,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    let flat = UIImage(cgImage: context.makeImage()!)
    return flat.pngData()!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let url = URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon-1024.png")
try! flattenedPNG(draw(icon)).write(to: url)
print("wrote \(url.path)")
