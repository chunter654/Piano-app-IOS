import SwiftUI

struct ContentView: View {

    @StateObject private var range = KeyboardRangeController()
    @StateObject private var audio = PianoAudioEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            caseBackground

            if let failure = audio.failure {
                AudioErrorView(error: failure) {
                    audio.restart()
                }
            } else {
                instrument
            }
        }
        .preferredColorScheme(.dark)
        // Keep the home indicator out of the way, and stop a swipe near the
        // bottom of the keyboard from being read as a system gesture.
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .bottom)
        .task {
            audio.startIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                audio.enterForeground()
            case .background:
                audio.enterBackground()
            default:
                // `.inactive` covers Control Centre and the app switcher, where
                // the audio session is still ours. Nothing to do.
                break
            }
        }
    }

    /// The wooden case. Built from tone rather than texture: a vertical fall of
    /// warm browns, the faintest vertical banding for grain, a sheen where the
    /// light falls, and darkened outer edges so the panel turns away at the
    /// sides. Nothing here should be identifiable as a wood photograph.
    private var caseBackground: some View {
        ZStack {
            LinearGradient(colors: [Theme.woodLightColor, Theme.woodMidColor, Theme.woodDarkColor],
                           startPoint: .top, endPoint: .bottom)

            // Broad tonal drift across the board, beneath the figure.
            LinearGradient(colors: Theme.woodGrain, startPoint: .leading, endPoint: .trailing)
                .blendMode(.overlay)

            // The grain itself, drawn once and cached.
            WoodGrainOverlay()

            // Light falls on the case after the grain, so it lights the figure too.
            RadialGradient(colors: [Color.white.opacity(0.055), .clear],
                           center: UnitPoint(x: 0.28, y: 0.10),
                           startRadius: 8, endRadius: 560)
                .blendMode(.softLight)

            LinearGradient(colors: [Color.black.opacity(0.30), .clear, Color.black.opacity(0.36)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .ignoresSafeArea()
    }

    /// The instrument, in whichever arrangement is in force. The catch sits in
    /// the same corner either way: at the head of the right-hand column when the
    /// keyboard is a single run, and at the end of the range bar when it is
    /// stacked.
    private var instrument: some View {
        Group {
            switch range.mode {
            case .single: singleColumn
            case .twoRow: stacked
            }
        }
        // The margins around the keys are the wooden case, and they are the only
        // vertical space on the screen that is ours to spend: above and below
        // them sit the status bar and the home indicator, which are not. Pared
        // back to what still reads as a case rather than an edge.
        .padding(.vertical, 4)
        .padding(.horizontal, 7)
        .background(keybed)
        .padding(.horizontal, 11)
        .padding(.top, 4)
        .padding(.bottom, 5)
    }

    /// How much of the width the controls take beside the keyboard, and the gap
    /// between them and the keys. Every point taken off either is a point of key
    /// length gained, so this is the dial to turn if the keys ever feel short.
    ///
    /// There is a floor. The catch and the slider are both as wide as this
    /// column, and Apple puts the smallest comfortable target at 44 points.
    /// Below about 30 they become genuinely fiddly to hit, particularly the
    /// catch, which is a single small tap rather than a drag you can correct.
    ///
    /// The catch owns this number, because the stacked bar has to place it at
    /// the same distance from the edge as this column does.
    private static let controlColumnWidth: CGFloat = LayoutCatch.railWidth
    private static let controlColumnGap: CGFloat = 7

    private var singleColumn: some View {
        HStack(spacing: Self.controlColumnGap) {
            keyboard

            VStack(spacing: 10) {
                LayoutCatch(mode: range.mode, width: Self.controlColumnWidth) {
                    range.toggleMode()
                }
                RangeSlider(range: range)
            }
            .frame(width: Self.controlColumnWidth)
        }
    }

    /// Two octaves, stepped a semitone at a time. No slider here: the window is
    /// anchored rather than scrolled, so the arrows are the control.
    private var stacked: some View {
        VStack(spacing: 10) {
            RangeStepBar(range: range) { range.toggleMode() }
                .frame(height: 48)

            keyboard
        }
    }

    private var keyboard: some View {
        PianoKeyboard(
            position: range.position,
            visibleWhiteKeys: range.visibleWhiteKeys,
            startNote: range.startNote,
            mode: range.mode,
            onPress: { audio.noteOn($0.midi) },
            onRelease: { audio.noteOff($0.midi) }
        )
    }

    /// The recess the keys sit in: dark, with the case shadowing its inside edge
    /// and a bead of light along the rim.
    private var keybed: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return shape
            .fill(Theme.keybedColor)
            .overlay(
                shape
                    .stroke(Theme.keybedShadowColor, lineWidth: 4)
                    .blur(radius: 4)
                    .clipShape(shape)
            )
            .overlay(shape.strokeBorder(Theme.caseHighlightColor, lineWidth: 0.75))
    }
}

#Preview {
    ContentView()
}
