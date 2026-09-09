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
            engraving
                .frame(width: Self.plateWidth, height: Self.plateHeight)
                // Exactly the width it is given, so the target never hangs over
                // the keys and never steals room from anything beside it.
                .frame(width: width, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftCapStyle(capSize: CGSize(width: Self.plateWidth,
                                                  height: Self.plateHeight)))
        .accessibilityLabel("Keyboard arrangement")
        .accessibilityValue(mode == .single ? "Single column" : "Two rows")
        .accessibilityHint(mode == .single ? "Switches to two stacked rows"
                                          : "Switches to one continuous keyboard")
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
