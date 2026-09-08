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

    private static let trackWidth: CGFloat = 9
    private static let thumbWidth: CGFloat = 27
    private static let minimumThumbHeight: CGFloat = 34
    /// How far past the thumb still counts as grabbing it.
    private static let grabSlack: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let visibleFraction = range.visibleWhiteKeys
                / Double(KeyboardRangeController.whiteKeyCount)
            let thumbHeight = max(Self.minimumThumbHeight, height * CGFloat(visibleFraction))
            let travel = max(1, height - thumbHeight)

            ZStack(alignment: .top) {
                track
                thumb
                    .frame(width: Self.thumbWidth, height: thumbHeight)
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
        RoundedRectangle(cornerRadius: Self.trackWidth / 2, style: .continuous)
            .fill(
                LinearGradient(colors: [Theme.trackTop, Theme.trackBottom],
                               startPoint: .leading, endPoint: .trailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.trackWidth / 2, style: .continuous)
                    .strokeBorder(Theme.trackRim, lineWidth: 0.5)
            )
            .frame(width: Self.trackWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var thumb: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(
                LinearGradient(colors: [Theme.brassHighlight, Theme.brassMid, Theme.brassShadow],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                LinearGradient(colors: [Color.white.opacity(0.13), .clear, Color.black.opacity(0.13)],
                               startPoint: .leading, endPoint: .trailing)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Theme.brassEdge, lineWidth: 0.75)
            )
            .overlay(grip)
            .shadow(color: Color(Theme.shadow).opacity(0.55), radius: 3, x: 0, y: 2)
    }

    /// Three machined lines across the middle, so the thumb reads as something
    /// milled rather than drawn.
    private var grip: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(Theme.brassEdge.opacity(0.45))
                    .frame(width: Self.thumbWidth * 0.42, height: 1)
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
                Color.clear.frame(width: 44, height: 1)
                Spacer(minLength: 0)

                StepButton(glyph: "\u{2039}",
                           label: "Move keyboard down one octave",
                           isEnabled: range.canStepDown) {
                    step { range.stepOctave(-1) }
                }
                Color.clear.frame(width: Self.centreChannel, height: 1)
                StepButton(glyph: "\u{203A}",
                           label: "Move keyboard up one octave",
                           isEnabled: range.canStepUp) {
                    step { range.stepOctave(1) }
                }

                Spacer(minLength: 0)
                LayoutCatch(mode: range.mode, action: onToggleArrangement)
            }
        }
    }

    /// A light tap confirms the step, and stays silent at the ends of the piano.
    private func step(_ move: () -> Bool) {
        guard move() else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct StepButton: View {

    /// Sized so the chevron stands about as tall as the capitals of the range
    /// beside it. The system serif draws a much sturdier chevron than the
    /// script face this started out in, and at the old size it towered over
    /// the lettering rather than accompanying it. The button around it keeps
    /// its full size, so the target stays as easy to hit as before.
    private static let glyphSize: CGFloat = 40

    /// A guillemet from the same face, rather than a system chevron, so the
    /// arrows are lettered in the same hand as the range.
    let glyph: String
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(glyph)
                .font(Theme.letteringFont(Self.glyphSize))
                .offset(y: Theme.letteringVerticalCorrection(of: glyph, size: Self.glyphSize))
                .foregroundStyle(isEnabled
                                 ? Theme.brassTextColor
                                 : Theme.brassTextColor.opacity(0.35))
                .frame(width: 46, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.keybedColor.opacity(isEnabled ? 0.85 : 0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.trackRim.opacity(isEnabled ? 0.6 : 0.25), lineWidth: 0.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityHint(isEnabled ? "" : "The keyboard is already at the end of the piano")
    }
}
