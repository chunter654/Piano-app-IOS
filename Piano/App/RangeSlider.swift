import SwiftUI
import UIKit

/// The range selector, running down the back edge of the keyboard.
///
/// Its travel is the whole 88-key piano and the thumb is the portion of it
/// currently under your fingers, sized in proportion. Dragging is continuous:
/// the keyboard slides rather than stepping, so there is nothing here that
/// quantises the movement.
struct RangeSlider: View {

    @ObservedObject var range: KeyboardRangeController

    /// Where the thumb sat when the finger landed on it, or nil when the
    /// drag began somewhere else and is being ignored.
    @State private var grabbedFrom: CGFloat?
    /// Whether the current drag has been judged yet. A drag is accepted or
    /// rejected once, when it starts, not continuously as it moves.
    @State private var isJudged = false
    /// The zoom when the pinch began, so the gesture scales from where it
    /// started rather than compounding on every callback.
    @State private var zoomAtPinchStart: Double?

    private static let trackWidth: CGFloat = 5
    /// The thumb is widest when it is shortest and narrowest when it is longest.
    ///
    /// Its length already reports how much of the piano is on screen, so this is
    /// not new information, it is compensation. A long thumb is trivially easy to
    /// catch and can afford to be slender, while a short one has almost nothing
    /// to take hold of and needs the mass. Between them the handle keeps sane
    /// proportions instead of becoming a stub at one end of the zoom and a ribbon
    /// at the other.
    private static let widestThumb: CGFloat = 24
    private static let narrowestThumb: CGFloat = 17
    private static let minimumThumbHeight: CGFloat = 34
    /// How far past the thumb still counts as grabbing it.
    private static let grabSlack: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let visibleFraction = range.visibleWhiteKeys
                / Double(KeyboardRangeController.whiteKeyCount)
            let thumbHeight = max(Self.minimumThumbHeight, height * CGFloat(visibleFraction))
            let width = Self.thumbWidth(showing: range.visibleWhiteKeys)
            let travel = max(1, height - thumbHeight)

            ZStack(alignment: .top) {
                track
                BrassBar(axis: .vertical, thickness: width)
                    .frame(width: width, height: thumbHeight)
                    .offset(y: CGFloat(range.progress) * travel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Touches that miss the thumb are ignored. Pressing the track used
            // to fling the keyboard to wherever the finger happened to land,
            // which is easy to do by accident and hard to undo.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isJudged {
                            isJudged = true
                            let thumbTop = CGFloat(range.progress) * travel
                            let reach = (thumbTop - Self.grabSlack)
                                ... (thumbTop + thumbHeight + Self.grabSlack)
                            grabbedFrom = reach.contains(value.startLocation.y) ? thumbTop : nil
                        }
                        guard let origin = grabbedFrom else { return }
                        scroll(to: origin + value.translation.height, travel: travel)
                    }
                    .onEnded { _ in
                        isJudged = false
                        grabbedFrom = nil
                    }
            )
            // Pinching the bar zooms the keyboard. It lives here rather than on
            // the keys because the keyboard tracks every finger separately to
            // make chords and sliding work, and a pinch there would be read as
            // two notes.
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let base = zoomAtPinchStart ?? range.visibleWhiteKeys
                        zoomAtPinchStart = base
                        // Spreading the fingers magnifies, which means fewer
                        // keys on screen, so the count divides rather than
                        // multiplies.
                        range.setVisibleWhiteKeys(base / Double(value.magnification))
                    }
                    .onEnded { _ in zoomAtPinchStart = nil }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Keyboard range")
        .accessibilityValue(range.spokenName)
        .accessibilityHint("Swipe up or down to move the keyboard by one key")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: range.step(by: 1)
            case .decrement: range.step(by: -1)
            @unknown default: break
            }
        }
    }

    /// Interpolated across the zoom range rather than taken from the height of
    /// the thumb, so it depends on how much piano is on screen and not on how
    /// tall the screen happens to be.
    private static func thumbWidth(showing keys: Double) -> CGFloat {
        let lowest = KeyboardRangeController.minVisibleWhiteKeys
        let highest = KeyboardRangeController.maxVisibleWhiteKeys
        guard highest > lowest else { return widestThumb }
        let travelled = min(max((keys - lowest) / (highest - lowest), 0), 1)
        return widestThumb - CGFloat(travelled) * (widestThumb - narrowestThumb)
    }

    /// Moves the thumb by however far the finger has travelled since it landed,
    /// rather than centring it on the finger. That keeps the thumb under the
    /// part of it you actually grabbed, and nothing quantises the movement.
    private func scroll(to proposedTop: CGFloat, travel: CGFloat) {
        let top = min(max(proposedTop, 0), travel)
        let fraction = travel > 0 ? Double(top / travel) : 0
        range.setPosition(fraction * range.maxPosition)
    }
    // MARK: - Hardware

    private var track: some View {
        Groove(axis: .vertical)
            .frame(width: Self.trackWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}/// The stacked arrangement's range control: the whole piano in miniature, with
/// the two octaves you are looking at picked out of it.
///
/// A slider tells you a proportion. This tells you a place. The keys are drawn
/// where they actually fall, so C is where C is, and the dimmed part keeps the
/// shape of the instrument visible so you never lose your bearings while moving.
///
/// It moves chromatically. The rows no longer always begin on a C, which was a
/// deliberate property while the arrows stepped by octaves, but there is nothing
/// left to infer from a label when you can see where you are.
struct RangeStepBar: View {

    @ObservedObject var range: KeyboardRangeController
    let onToggleArrangement: () -> Void

    /// Where the window began when this drag started, and whether the drag began
    /// on it at all. Judged once, as the other slider does it, so a touch that
    /// misses is ignored for its whole duration rather than flinging the
    /// keyboard somewhere by accident.
    @State private var grabbedFrom: Int?
    @State private var isJudged = false

    private static let stripHeight: CGFloat = 38     // the catch beside it
    private static let catchWidth: CGFloat = 30
    private static let gap: CGFloat = 10
    private static let grabSlack: CGFloat = 10

    private static let lowest = PianoNote.lowest.midi
    private static let semitones = CGFloat(PianoNote.highest.midi - PianoNote.lowest.midi)

    var body: some View {
        HStack(spacing: Self.gap) {
            GeometryReader { geo in
                let size = geo.size
                strip(size: size)
                    .frame(width: size.width, height: Self.stripHeight)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(drag(across: size.width))
            }
            LayoutCatch(mode: range.mode, width: Self.catchWidth,
                        action: onToggleArrangement)
        }
        .accessibilityElement()
        .accessibilityLabel("Keyboard range")
        .accessibilityValue(range.stackedSpokenName)
        .accessibilityHint("Swipe up or down to move the keyboard by a semitone")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: range.setStartNote(range.startNote + 1)
            case .decrement: range.setStartNote(range.startNote - 1)
            @unknown default: break
            }
        }
    }

    // MARK: - The piano, small

    private func strip(size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return Canvas { context, canvas in
            draw(in: context, size: CGSize(width: canvas.width, height: Self.stripHeight))
        }
        .background(Theme.keybedColor)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.capEdge, lineWidth: 0.75))
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let whites = KeyboardLayout.whiteMidis
        let whiteWidth = size.width / CGFloat(whites.count)
        let window = range.startNote ..< (range.startNote + KeyboardRangeController.stackedSpan)

        for (index, midi) in whites.enumerated() {
            let rect = CGRect(x: CGFloat(index) * whiteWidth, y: 0,
                              width: max(0.5, whiteWidth - 0.6), height: size.height)
            context.fill(Path(rect),
                         with: .color(window.contains(midi) ? Theme.stripNatural
                                                            : Theme.stripNaturalDim))
        }

        let accidentalWidth = whiteWidth * KeyboardLayout.blackThicknessRatio
        let accidentalHeight = size.height * KeyboardLayout.blackLengthRatio
        for (index, midi) in whites.enumerated() where index < whites.count - 1 {
            let sharp = midi + 1
            guard PianoNote(midi: sharp).isBlack else { continue }
            let centre = CGFloat(index + 1) * whiteWidth
            let rect = CGRect(x: centre - accidentalWidth / 2, y: 0,
                              width: accidentalWidth, height: accidentalHeight)
            context.fill(Path(rect),
                         with: .color(window.contains(sharp) ? Theme.stripAccidental
                                                             : Theme.stripAccidentalDim))
        }

        // A hairline round the keys in view, drawn to their edges rather than to
        // the window's exact pitch, so the frame and the lit keys never disagree.
        let lit = whites.enumerated().filter { window.contains($0.element) }.map(\.offset)
        if let first = lit.first, let last = lit.last {
            let frame = CGRect(x: CGFloat(first) * whiteWidth, y: 0,
                               width: CGFloat(last - first + 1) * whiteWidth - 0.6,
                               height: size.height)
            context.stroke(Path(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2),
                           with: .color(Theme.brassTextColor.opacity(0.5)), lineWidth: 1)
        }
    }

    // MARK: - Moving it

    private func drag(across width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard width > 0 else { return }
                let perSemitone = width / Self.semitones
                if !isJudged {
                    isJudged = true
                    let left = CGFloat(range.startNote - Self.lowest) * perSemitone
                    let span = CGFloat(KeyboardRangeController.stackedSpan) * perSemitone
                    let reach = (left - Self.grabSlack) ... (left + span + Self.grabSlack)
                    grabbedFrom = reach.contains(value.startLocation.x) ? range.startNote : nil
                }
                guard let origin = grabbedFrom else { return }
                let moved = Int((value.translation.width / perSemitone).rounded())
                let before = range.startNote
                if range.setStartNote(origin + moved), (range.startNote % 12) == 0,
                   before != range.startNote {
                    // A knock on every C, which is how you would count your way
                    // along a real keyboard. One per semitone would rattle.
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { _ in
                isJudged = false
                grabbedFrom = nil
            }
    }
}

/// The channel a slider runs in, on either axis.
///
/// Shaded across its width rather than along its length: the near wall falls
/// into shadow and the far one catches what light reaches into the cut, with the
/// faintest brass along the broken lip. Filled flat it stops being a groove and
/// becomes a dark line drawn on the wood.
struct Groove: View {

    let axis: Axis

    var body: some View {
        let across = LinearGradient(colors: [Theme.grooveNearWall, Theme.grooveFarWall],
                                    startPoint: axis == .vertical ? .leading : .top,
                                    endPoint: axis == .vertical ? .trailing : .bottom)
        let lip = LinearGradient(colors: [.clear, Theme.grooveLip],
                                 startPoint: axis == .vertical ? .leading : .top,
                                 endPoint: axis == .vertical ? .trailing : .bottom)
        return Capsule(style: .continuous)
            .fill(across)
            .overlay(Capsule(style: .continuous).strokeBorder(lip, lineWidth: 0.5))
    }
}

/// The bar of turned brass that rides in a groove, on either axis.
///
/// The light runs across the bar rather than along it. A cylinder lit from one
/// side is bright along a line and falls away to both edges, which is what makes
/// this read as a machined part. A fade along its length is what every slider on
/// every phone does, and no amount of colour rescues that.
///
/// Defined once and used by both arrangements, because they are the same piece
/// of hardware seen twice and describing them separately is how two controls
/// stop matching.
struct BrassBar: View {

    let axis: Axis
    /// The measurement across the bar, which the machined lines are cut from.
    let thickness: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
        return shape
            .fill(
                LinearGradient(stops: [
                    .init(color: Theme.brassShadow, location: 0),
                    .init(color: Theme.brassHighlight, location: 0.30),
                    .init(color: Theme.brassMid, location: 0.66),
                    .init(color: Theme.brassShadow, location: 1),
                ], startPoint: axis == .vertical ? .leading : .top,
                   endPoint: axis == .vertical ? .trailing : .bottom)
            )
            // The ends are cut faces, turned away from the light.
            .overlay(
                LinearGradient(stops: [
                    .init(color: Color.black.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.09),
                    .init(color: .clear, location: 0.91),
                    .init(color: Color.black.opacity(0.35), location: 1),
                ], startPoint: axis == .vertical ? .top : .leading,
                   endPoint: axis == .vertical ? .bottom : .trailing)
            )
            .overlay(knurl)
            .clipShape(shape)
            .shadow(color: Color(Theme.shadow).opacity(0.38), radius: 1.5, x: 0, y: 0.5)
    }

    /// Two fine lines turned into the middle of the bar, where a thumb sits.
    @ViewBuilder
    private var knurl: some View {
        let length = thickness * 0.52
        if axis == .vertical {
            VStack(spacing: 3.5) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule().fill(Theme.brassEdge.opacity(0.30))
                        .frame(width: length, height: 0.75)
                }
            }
        } else {
            HStack(spacing: 3.5) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule().fill(Theme.brassEdge.opacity(0.30))
                        .frame(width: 0.75, height: length)
                }
            }
        }
    }
}

/// The cap every pressable control on the rail wears.
///
/// Defined once and worn by both the arrows and the layout catch, because they
/// are the same object seen twice and the surest way for two controls to stop
/// matching is to describe them separately.
///
/// The face is domed rather than flat: light gathers just above the middle and
/// falls away, and the bottom inside darkens as the face turns under. The edge
/// is one even weight the whole way round. A bevel that varies reads as milled
/// metal, and fading half of it away leaves the shape with no bottom edge, so
/// you cannot tell where the button ends.
struct SoftCap: View {

    var cornerRadius: CGFloat = 9
    var isEnabled: Bool = true

    var body: some View {
        GeometryReader { geo in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            shape
                .fill(
                    LinearGradient(colors: [Theme.capFaceTop, Theme.capFaceBottom],
                                   startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    RadialGradient(colors: [Theme.capDome, .clear],
                                   center: UnitPoint(x: 0.5, y: 0.34),
                                   startRadius: 1,
                                   // Scaled to the cap, so the dome sits the same
                                   // way on the wide arrows as on the narrow catch.
                                   endRadius: max(geo.size.width, geo.size.height) * 0.62)
                )
                .overlay(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.55),
                        .init(color: Theme.capUnderside.opacity(0.55), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                )
                .overlay(shape.strokeBorder(Theme.capEdge, lineWidth: 0.75))
                .clipShape(shape)
                .opacity(isEnabled ? 1 : 0.45)
        }
    }
}

/// Draws a cap behind the button and takes it down while it is held.
///
/// A button that does not move when pressed never feels soft, however carefully
/// it is shaded. This is the part that does that work.
struct SoftCapStyle: ButtonStyle {

    let capSize: CGSize
    var cornerRadius: CGFloat = 9
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed && isEnabled
        return configuration.label
            .background(
                SoftCap(cornerRadius: cornerRadius, isEnabled: isEnabled)
                    .frame(width: capSize.width, height: capSize.height)
                    .brightness(down ? -0.035 : 0)
                    .shadow(color: Color(Theme.shadow).opacity(down ? 0.3 : 0.5),
                            radius: down ? 1 : 2.5, x: 0, y: down ? 0.5 : 1.5)
                    .scaleEffect(down ? 0.97 : 1)
                    .animation(.easeOut(duration: 0.09), value: down)
            )
    }
}
