import SwiftUI

/// Shown instead of the keyboard when there is no sound to play, so the app
/// never presents a piano that silently does nothing.
struct AudioErrorView: View {

    let error: PianoAudioError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.secondaryTextColor)

            Text(error.errorDescription ?? "Audio is unavailable.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.primaryTextColor)
                .multilineTextAlignment(.center)

            if let detail = error.detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }

            Button(action: retry) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primaryTextColor)
                    .frame(minWidth: 140, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.keybedColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(32)
    }
}
