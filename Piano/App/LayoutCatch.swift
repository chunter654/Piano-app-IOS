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

    private static let plateWidth: CGFloat = 30
    private static let plateHeight: CGFloat = 38

    var body: some View {
        Button(action: action) {
            plate
                .frame(width: Self.plateWidth, height: Self.plateHeight)
                // Exactly the width it is given, so the target never hangs over
                // the keys and never steals room from anything beside it.
                .frame(width: width, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keyboard arrangement")
        .accessibilityValue(mode == .single ? "Single column" : "Two rows")
        .accessibilityHint(mode == .single ? "Switches to two stacked rows"
                                          : "Switches to one continuous keyboard")
    }    /// A cap that sits proud of the rail, not a hollow cut into it. This is the
    /// only control here you press rather than drag, and it should look like
    /// something that goes down when you do.
    ///
    /// Outlined the whole way round in brass, brighter along the top lip than
    /// the bottom. An earlier version faded the lower half of that edge away
    /// to nothing, on the theory that a bevel reads as hardware where an
    /// even stroke reads as a rectangle drawn on a screen. It does, but it
    /// also left the shape with no bottom edge, so you could not tell where
    /// the button ended or whether it was one. Both ends of the fade are
    /// visible now.
    private var plate: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(
                LinearGradient(colors: [Theme.capFaceTop, Theme.capFaceBottom],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Theme.capEdgeTop, Theme.capEdgeBottom],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color(Theme.shadow).opacity(0.5), radius: 2, x: 0, y: 1.5)
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
