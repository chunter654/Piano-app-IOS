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
}
/// The stacked arrangement's range control: a slider showing where its two
/// octaves sit on the piano.
///
/// The track is the whole instrument and the thumb is the part of it on screen,
/// which is the same idea the single column uses, so both arrangements answer
/// "where am I" the same way.
///
/// The window can only rest on one of six Cs, but the thumb glides rather than
/// snapping, so your finger moves smoothly while the keyboard steps underneath.
/// On release it settles onto the octave the instrument actually reached: that
/// is the one moment it must not be left showing a position that is not real.
///
/// Note where the thumb stops at the left. The lowest this arrangement goes is
/// C1, so the bottom three notes of the piano are never in view, and the gap is
/// the truth rather than a rounding error.
struct RangeStepBar: View {

    @ObservedObject var range: KeyboardRangeController
    let onToggleArrangement: () -> Void

    /// Where the finger has dragged to, as a fraction of the whole piano, or nil
    /// when the thumb is resting on the octave the keyboard is actually at.
    @State private var glide: Double?
    /// Whether this drag began on the thumb. Judged once, as the other slider
    /// does it, so a touch that misses is ignored for its whole duration.
    @State private var grabbed: Bool?

    private static let trackThickness: CGFloat = 5
    private static let thumbThickness: CGFloat = 20
    private static let catchWidth: CGFloat = 30
    private static let gap: CGFloat = 10
    private static let grabSlack: CGFloat = 12

    private static let lowest = Double(PianoNote.lowest.midi)
    private static let semitones = Double(PianoNote.highest.midi - PianoNote.lowest.midi)

    /// The share of the piano the two visible octaves take up.
    private static var thumbShare: Double {
        Double(KeyboardRangeController.stackedSpan) / semitones
    }

    /// The two ends of the thumb's travel, in the same fraction.
    private static var lowestFraction: Double {
        (Double(KeyboardRangeController.octaveStarts.first ?? 24) - lowest) / semitones
    }
    private static var highestFraction: Double {
        (Double(KeyboardRangeController.octaveStarts.last ?? 84) - lowest) / semitones
    }

    private var restingFraction: Double {
        (Double(range.startNote) - Self.lowest) / Self.semitones
    }

    var body: some View {
        HStack(spacing: Self.gap) {
            GeometryReader { geo in
                let full = geo.size.width
                let thumbWidth = CGFloat(Self.thumbShare) * full
                let fraction = glide ?? restingFraction

                ZStack(alignment: .leading) {
                    Groove(axis: .horizontal)
                        .frame(height: Self.trackThickness)
                        .frame(maxHeight: .infinity)
                    BrassBar(axis: .horizontal, thickness: Self.thumbThickness)
                        .frame(width: thumbWidth, height: Self.thumbThickness)
                        .offset(x: CGFloat(fraction) * full)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if grabbed == nil {
                                let left = CGFloat(restingFraction) * full
                                let reach = (left - Self.grabSlack)
                                    ... (left + thumbWidth + Self.grabSlack)
                                grabbed = reach.contains(value.startLocation.x)
                            }
                            guard grabbed == true, full > 0 else { return }
                            let moved = Double(value.translation.width / full)
                            drag(to: restingOrGlideStart + moved)
                        }
                        .onEnded { _ in
                            grabbed = nil
                            glideStart = nil
                            // Settle onto the octave the keyboard actually reached.
                            withAnimation(.easeOut(duration: 0.16)) { glide = nil }
                        }
                )
            }
            LayoutCatch(mode: range.mode, width: Self.catchWidth,
                        action: onToggleArrangement)
        }
        .accessibilityElement(children: .contain)
    }

    /// Where the thumb sat when this drag began, so the movement is relative and
    /// the thumb stays under the part of it you took hold of.
    @State private var glideStart: Double?

    private var restingOrGlideStart: Double {
        if let start = glideStart { return start }
        return restingFraction
    }

    private func drag(to proposed: Double) {
        if glideStart == nil { glideStart = restingFraction }
        let held = min(max(proposed, Self.lowestFraction), Self.highestFraction)
        glide = held
        // The keyboard steps to the nearest octave while the thumb keeps moving,
        // and each step knocks. That feedback used to come from the two arrows
        // this slider replaced, and it is worth more here: the thumb glides, so
        // without it there is nothing to tell you the instrument has moved.
        let note = Self.lowest + held * Self.semitones
        if range.setStartNote(Int(note.rounded())) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
