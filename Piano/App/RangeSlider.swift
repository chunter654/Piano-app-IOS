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
    private static let widestThumb: CGFloat = 26
    private static let narrowestThumb: CGFloat = 12
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
                thumb(width: width)
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

    // MARK: - Hardware    /// A channel cut into the case.
    ///
    /// Shaded across its width, not down its length: the near wall falls into
    /// shadow and the far one catches what light reaches into the cut, with the
    /// faintest brass along the lip where the edge is broken. Fill it flat and
    /// it stops being a groove and becomes a dark line drawn on the wood.
    private var track: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(colors: [Theme.grooveNearWall, Theme.grooveFarWall],
                               startPoint: .leading, endPoint: .trailing)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.clear, Theme.grooveLip],
                                       startPoint: .leading, endPoint: .trailing),
                        lineWidth: 0.5
                    )
            )
            .frame(width: Self.trackWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A bar of turned brass, seated in the groove.
    ///
    /// The light runs across it rather than down it. A cylinder lit from one
    /// side is bright along a line and falls away to both edges, and that is
    /// what makes this read as a machined part; a top-to-bottom fade is what
    /// every slider on every phone does, and no amount of colour rescues it.
    ///
    /// Its width is not up for negotiation. This is something you find with a
    /// thumb without looking, and elegance that costs you the target is not
    /// elegance.
    private func thumb(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .fill(
                LinearGradient(stops: [
                    .init(color: Theme.brassShadow, location: 0),
                    .init(color: Theme.brassHighlight, location: 0.30),
                    .init(color: Theme.brassMid, location: 0.66),
                    .init(color: Theme.brassShadow, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            )
            // The ends are cut faces, turned away from the light.
            .overlay(
                LinearGradient(stops: [
                    .init(color: Color.black.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.09),
                    .init(color: .clear, location: 0.91),
                    .init(color: Color.black.opacity(0.35), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            )
            .overlay(knurl(width: width))
            // No outline. The gradient already falls to shadow at both edges,
            // which defines the shape without a dark ring round it: the ring is
            // what was reading as weight, and weight is what made it look bulky.
            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            .shadow(color: Color(Theme.shadow).opacity(0.38), radius: 1.5, x: 0, y: 0.5)
    }

    /// Two fine lines turned into the middle of the bar, where a thumb sits.
    /// Enough to say the part was machined, far short of the milled grip this
    /// carried before, which made it the loudest thing on the screen.
    private func knurl(width: CGFloat) -> some View {
        VStack(spacing: 3.5) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule()
                    .fill(Theme.brassEdge.opacity(0.30))
                    .frame(width: width * 0.52, height: 0.75)
            }
        }
    }
}

/// The stacked arrangement's range control: a semitone down, the range it spans,
/// and a semitone up. It replaces the slider entirely in that mode, because a
/// window that steps a semitone at a time is not something you slide.
struct RangeStepBar: View {

    @ObservedObject var range: KeyboardRangeController
    let onToggleArrangement: () -> Void
    /// The stack's own gap between neighbouring controls.
    private static let controlSpacing: CGFloat = 8

    /// The clear channel the range sits in, between the two arrows. Fixed
    /// rather than flexible: a spacer here pushed the arrows out to the ends of
    /// the bar, a long way from the lettering they act on.
    private static let centreChannel: CGFloat = 105

    /// The catch, and the empty space reserved opposite it. One constant for
    /// both, because the pair being equal is what centres the range.
    private static let catchWidth: CGFloat = 44

    /// What the range has to fit within: the channel plus the stack's spacing
    /// on either side of it.
    private static var rangeWidth: CGFloat { centreChannel + controlSpacing * 2 }

    /// Deliberately quiet. The range is a label on the instrument, not a
    /// headline, and at anything like the size it started at it competed with
    /// the keys. Well under the channel, so it is drawn at the size named here
    /// rather than shrunk to fit.
    private static let rangeTextSize: CGFloat = 22

    var body: some View {
        // The range sits centred on the whole bar, with every control laid over
        // it. Placing the text beside the controls instead pushes it off-centre
        // by half the catch's width, because nothing balances the catch on the
        // left.
        ZStack {
            Text(range.stackedDisplayName)
                .font(Theme.letteringFont(Self.rangeTextSize))
                .kerning(0.5)
                .foregroundStyle(Theme.brassTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                // Held to the channel the arrows leave it, so it cannot run
                // under one however the range comes to be written.
                .frame(maxWidth: Self.rangeWidth)
                .offset(y: Theme.letteringVerticalCorrection(of: range.stackedDisplayName,
                                                              size: Self.rangeTextSize))
                .accessibilityLabel("Keyboard range")
                .accessibilityValue(range.stackedSpokenName)

            HStack(spacing: Self.controlSpacing) {
                // Reserves the catch's width on the left, so the pair of arrows
                // centres on the same line the range does.
                Color.clear.frame(width: Self.catchWidth, height: 1)
                Spacer(minLength: 0)

                StepButton(pointsLeft: true,
                           label: "Move keyboard down one octave",
                           isEnabled: range.canStepDown) {
                    step { range.stepOctave(-1) }
                }
                Color.clear.frame(width: Self.centreChannel, height: 1)
                StepButton(pointsLeft: false,
                           label: "Move keyboard up one octave",
                           isEnabled: range.canStepUp) {
                    step { range.stepOctave(1) }
                }

                Spacer(minLength: 0)
                LayoutCatch(mode: range.mode, width: Self.catchWidth,
                            action: onToggleArrangement)
            }
        }
    }

    /// A light tap confirms the step, and stays silent at the ends of the piano.
    private func step(_ move: () -> Bool) {
        guard move() else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
/// A chevron drawn rather than typed.
///
/// A glyph carries whatever weight its typeface gives it, and every face that
/// ships with the system draws these far heavier than a piece of brass inlay
/// would be. A stroked path can be as fine as the hardware it stands for.
private struct Chevron: Shape {

    let pointsLeft: Bool

    func path(in rect: CGRect) -> Path {
        let back = pointsLeft ? rect.maxX : rect.minX
        let tip = pointsLeft ? rect.minX : rect.maxX
        var path = Path()
        path.move(to: CGPoint(x: back, y: rect.minY))
        path.addLine(to: CGPoint(x: tip, y: rect.midY))
        path.addLine(to: CGPoint(x: back, y: rect.maxY))
        return path
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

private struct StepButton: View {

    /// Fine enough to read as inlay rather than as an icon. Round caps and
    /// joins, because a milled brass chevron has no sharp corners.
    private static let stroke: CGFloat = 1.4
    private static let chevronSize = CGSize(width: 8, height: 15)

    /// What you can hit, which is not what you can see. The target keeps the
    /// full 46 by 44 it has always had, so shrinking the cap inside it to
    /// match the catch costs nothing in reach, and the rail does not move
    /// because the stack is laid out from the target rather than the cap.
    private static let targetSize = CGSize(width: 46, height: 44)
    private static let capSize = CGSize(width: 30, height: 38)

    let pointsLeft: Bool
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Chevron(pointsLeft: pointsLeft)
                .stroke(style: StrokeStyle(lineWidth: Self.stroke,
                                           lineCap: .round, lineJoin: .round))
                .foregroundStyle(isEnabled
                                 ? Theme.brassTextColor
                                 : Theme.brassTextColor.opacity(0.3))
                .frame(width: Self.chevronSize.width, height: Self.chevronSize.height)
                // The target is unchanged; only what is drawn inside it has.
                .frame(width: Self.targetSize.width, height: Self.targetSize.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftCapStyle(capSize: Self.capSize, isEnabled: isEnabled))
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityHint(isEnabled ? "" : "The keyboard is already at the end of the piano")
    }
}
