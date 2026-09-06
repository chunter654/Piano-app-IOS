import SwiftUI
import UIKit

/// Procedural walnut grain for the case.
///
/// The grain is drawn once into an image and cached. That matters: the case
/// never changes, and re-rasterising it while the keyboard is being dragged
/// would be pure waste.
///
/// Lines wander by a sum of two slow sines plus a slight lean, so no two are
/// alike and nothing repeats; they are gathered into loose clusters the way
/// walnut figures rather than being spread evenly; and both lighter and darker
/// warm tones are used so the wood reads as grain rather than as shading. Every
/// value comes from a fixed seed, so the same board is drawn on every launch.
enum WoodGrain {

    /// Deterministic, so the case does not reshuffle itself between launches.
    private struct Seeded: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) {
            // Any non-zero state will do; xorshift is stuck at zero.
            state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
        }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    private static var cache: [String: UIImage] = [:]

    /// Walnut is not one brown. These are the tones its figure runs between:
    /// a pale sapwood tan, a reddish mid brown, and the near-black of the
    /// darkest veins. Mixing them is what stops the grain reading as a set of
    /// grey lines drawn over a flat panel.
    private static let paleFigure = UIColor(red: 0.616, green: 0.482, blue: 0.333, alpha: 1)
    private static let lightFigure = UIColor(red: 0.522, green: 0.365, blue: 0.227, alpha: 1)
    private static let midFigure = UIColor(red: 0.263, green: 0.169, blue: 0.098, alpha: 1)
    private static let darkFigure = UIColor(red: 0.071, green: 0.043, blue: 0.027, alpha: 1)

    static func image(size: CGSize, scale: CGFloat) -> UIImage {
        let key = "\(Int(size.width))x\(Int(size.height))@\(scale)"
        if let cached = cache[key] { return cached }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.setLineCap(.round)
            var rng = Seeded(seed: 0x7A11_9E42_C0DE_1F05)

            // Loose clusters, as a board figures: most lines sit near one of a
            // handful of centres, with a scattering in between.
            let clusterCount = 13
            let clusters: [CGFloat] = (0..<clusterCount).map { _ in
                CGFloat.random(in: -0.08...1.08, using: &rng) * size.width
            }

            // Broad, soft streaks first: walnut's darker veins, which carry the
            // tonal variation the fine lines sit inside. Wide and very faint, so
            // they read as the wood turning rather than as marks on it.
            for _ in 0..<16 {
                let centre = CGFloat.random(in: -0.05...1.05, using: &rng) * size.width
                let drift = CGFloat.random(in: -18...18, using: &rng)
                let width = CGFloat.random(in: 9...34, using: &rng)
                let dark = Double.random(in: 0...1, using: &rng) < 0.6
                let alpha = CGFloat.random(in: 0.012...0.030, using: &rng)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: centre, y: -20))
                path.addCurve(to: CGPoint(x: centre + drift, y: size.height + 20),
                              control1: CGPoint(x: centre + drift * 0.8, y: size.height * 0.35),
                              control2: CGPoint(x: centre - drift * 0.5, y: size.height * 0.7))
                cg.setStrokeColor((dark ? midFigure : paleFigure).withAlphaComponent(alpha).cgColor)
                cg.setLineWidth(width)
                cg.addPath(path)
                cg.strokePath()
            }

            for _ in 0..<230 {
                let nearCluster = Double.random(in: 0...1, using: &rng) < 0.72
                let baseX: CGFloat
                if nearCluster, let centre = clusters.randomElement(using: &rng) {
                    baseX = centre + CGFloat.random(in: -26...26, using: &rng)
                } else {
                    baseX = CGFloat.random(in: -24...(size.width + 24), using: &rng)
                }

                // Two slow sines and a lean: enough wander to look grown, not
                // enough to look like a ripple.
                let amplitude1 = CGFloat.random(in: 1.5...9, using: &rng)
                let amplitude2 = CGFloat.random(in: 0.4...2.8, using: &rng)
                let frequency1 = CGFloat.random(in: 0.5...1.5, using: &rng)
                let frequency2 = CGFloat.random(in: 2.4...5.2, using: &rng)
                let phase1 = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                let phase2 = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                let lean = CGFloat.random(in: -0.05...0.05, using: &rng)

                let path = CGMutablePath()
                var y: CGFloat = -12
                var first = true
                while y <= size.height + 12 {
                    let t = y / max(size.height, 1)
                    let x = baseX
                        + lean * y
                        + amplitude1 * sin(t * frequency1 * 2 * .pi + phase1)
                        + amplitude2 * sin(t * frequency2 * 2 * .pi + phase2)
                    if first {
                        path.move(to: CGPoint(x: x, y: y))
                        first = false
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    y += 9
                }

                // Wider lines are held fainter, so weight and presence stay even.
                let width = CGFloat.random(in: 0.4...1.7, using: &rng)
                let faintness = 1 - (width - 0.4) / 1.3
                // Four tones rather than two, so no single line colour repeats
                // often enough to be noticed.
                let roll = Double.random(in: 0...1, using: &rng)
                let tone: UIColor
                let base: CGFloat
                switch roll {
                case ..<0.34: tone = darkFigure; base = 0.032
                case ..<0.62: tone = midFigure;  base = 0.030
                case ..<0.86: tone = lightFigure; base = 0.024
                default:      tone = paleFigure;  base = 0.020
                }
                let alpha = base + 0.050 * faintness * CGFloat.random(in: 0.45...1, using: &rng)

                cg.setStrokeColor(tone.withAlphaComponent(alpha).cgColor)
                cg.setLineWidth(width)
                cg.addPath(path)
                cg.strokePath()
            }
        }

        cache[key] = rendered
        return rendered
    }
}

/// The grain, sized to whatever it is placed over.
struct WoodGrainOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: WoodGrain.image(size: geometry.size,
                                           // Two points per pixel keeps hairlines
                                           // crisp without a third of the memory
                                           // a 3x bitmap would cost.
                                           scale: min(UITraitCollection.current.displayScale, 2)))
                .resizable()
        }
        .allowsHitTesting(false)
    }
}
