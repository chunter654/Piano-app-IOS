import SwiftUI

/// The catch that switches the keyboard between its two arrangements.
///
/// Built into the case below the slider rather than floated over the keys, so
/// the area above the keyboard stays clear. It is meant to read as a small piece
/// of hardware: an aged-brass plate with an arrangement engraved into it, one bar
/// for the single column and two for the stacked rows.
struct LayoutCatch: View {

    let mode: KeyboardLayoutMode

    /// Set by whoever places it, because the two arrangements give it
    /// different room. Letting it grow to fill instead cost the stacked bar
    /// its symmetry: it swallowed the slack the arrows were centred on and
    /// dragged the whole group seventeen points off centre.
    let width: CGFloat
    let action: () -> Void

    fileprivate static let plateWidth: CGFloat = 30
    fileprivate static let plateHeight: CGFloat = 38
    var body: some View {
        Button(action: action) {
            Color.clear
                // Exactly the width it is given, so the target never hangs over
                // the keys and never steals room from anything beside it.
                .frame(width: width, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(CapStyle(plate: plate))
        .accessibilityLabel("Keyboard arrangement")
        .accessibilityValue(mode == .single ? "Single column" : "Two rows")
        .accessibilityHint(mode == .single ? "Switches to two stacked rows"
                                          : "Switches to one continuous keyboard")
    }

    /// Draws the cap behind whatever the button contains, and takes it down
    /// while it is held.
    ///
    /// A button that does not move when you press it never feels soft, however
    /// it is shaded. This is the part that does the work.
    private struct CapStyle<Plate: View>: ButtonStyle {

        let plate: Plate

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(
                    plate
                        .frame(width: LayoutCatch.plateWidth,
                               height: LayoutCatch.plateHeight)
                        .brightness(configuration.isPressed ? -0.035 : 0)
                        .shadow(color: Color(Theme.shadow)
                                    .opacity(configuration.isPressed ? 0.3 : 0.5),
                                radius: configuration.isPressed ? 1 : 2.5,
                                x: 0,
                                y: configuration.isPressed ? 0.5 : 1.5)
                        .scaleEffect(configuration.isPressed ? 0.97 : 1)
                        .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
                )
        }
    }
    /// A soft cap, not a machined plate.
    ///
    /// The face is domed rather than flat: light gathers just above the middle
    /// and falls away, and the bottom inside darkens as the face turns under.
    /// The edge is one weight the whole way round, because a bevel that varies
    /// reads as milled metal, and because fading half of it away once left the
    /// shape with no bottom and you could not tell where the button ended.
    private var plate: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                LinearGradient(colors: [Theme.capFaceTop, Theme.capFaceBottom],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RadialGradient(colors: [Theme.capDome, .clear],
                               center: UnitPoint(x: 0.5, y: 0.34),
                               startRadius: 1, endRadius: 24)
            )
            .overlay(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.55),
                    .init(color: Theme.capUnderside.opacity(0.55), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.capEdge, lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(engraving)
    }

    /// Two lines for the two rows, one for the single column, which makes the
    /// mark count the thing it stands for. They are hairlines rather than
    /// bars: at this size a bar reads as a symbol borrowed from some other
    /// app, which is what the rest of this rail is trying not to look like.
    @ViewBuilder
    private var engraving: some View {
        switch mode.other {
        case .single:
            Capsule()
                .fill(Theme.brassTextColor.opacity(0.8))
                .frame(width: 2, height: 20)
        case .twoRow:
            VStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule()
                        .fill(Theme.brassTextColor.opacity(0.8))
                        .frame(width: 18, height: 2)
                }
            }
        }
    }
}
