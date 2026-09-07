import SwiftUI

/// The catch that switches the keyboard between its two arrangements.
///
/// Built into the case below the slider rather than floated over the keys, so
/// the area above the keyboard stays clear. It is meant to read as a small piece
/// of hardware: an aged-brass plate with an arrangement engraved into it, one bar
/// for the single column and two for the stacked rows.
struct LayoutCatch: View {

    let mode: KeyboardLayoutMode
    let action: () -> Void

    private static let plateWidth: CGFloat = 30
    private static let plateHeight: CGFloat = 38

    var body: some View {
        Button(action: action) {
            plate
                .frame(width: Self.plateWidth, height: Self.plateHeight)
                // A comfortable target around a deliberately small plate.
                .frame(width: 44, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keyboard arrangement")
        .accessibilityValue(mode == .single ? "Single column" : "Two rows")
        .accessibilityHint(mode == .single ? "Switches to two stacked rows"
                                          : "Switches to one continuous keyboard")
    }

    private var plate: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(colors: [Theme.brassHighlight, Theme.brassMid, Theme.brassShadow],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                LinearGradient(colors: [Color.white.opacity(0.13), .clear, Color.black.opacity(0.13)],
                               startPoint: .leading, endPoint: .trailing)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Theme.brassEdge, lineWidth: 0.75)
            )
            .overlay(engraving)
            .shadow(color: Color(Theme.shadow).opacity(0.55), radius: 3, x: 0, y: 2)
    }

    /// The arrangement the catch will switch to, not the one in force. The
    /// current arrangement is already the largest thing on the screen, so
    /// engraving it here would say nothing; engraving the destination says
    /// what the catch does.
    @ViewBuilder
    private var engraving: some View {
        switch mode.other {
        case .single:
            Capsule()
                .fill(Theme.brassEdge.opacity(0.55))
                .frame(width: 4, height: 20)
        case .twoRow:
            VStack(spacing: 5) {
                Capsule().fill(Theme.brassEdge.opacity(0.55)).frame(width: 17, height: 4)
                Capsule().fill(Theme.brassEdge.opacity(0.55)).frame(width: 17, height: 4)
            }
        }
    }
}
