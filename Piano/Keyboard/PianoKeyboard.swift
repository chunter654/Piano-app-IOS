import SwiftUI

/// Bridges the UIKit keyboard into SwiftUI.
///
/// Note events go straight from the touch handler to these closures and on to
/// the audio engine. No SwiftUI state sits on that path, which is what keeps
/// touch-to-sound short and stops a chord from triggering view updates.
struct PianoKeyboard: UIViewRepresentable {

    /// Where the viewport sits on the piano, in white keys from A0.
    let position: Double
    let startNote: Int
    let mode: KeyboardLayoutMode
    let onPress: (PianoNote) -> Void
    let onRelease: (PianoNote) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PianoKeyboardView {
        let view = PianoKeyboardView()
        view.delegate = context.coordinator
        view.mode = mode
        view.startNote = startNote
        view.position = position
        return view
    }

    func updateUIView(_ view: PianoKeyboardView, context: Context) {
        context.coordinator.parent = self
        view.mode = mode
        view.startNote = startNote
        view.position = position
    }

    final class Coordinator: PianoKeyboardViewDelegate {
        var parent: PianoKeyboard

        init(_ parent: PianoKeyboard) {
            self.parent = parent
        }

        func keyboardView(_ view: PianoKeyboardView, didPress note: PianoNote) {
            parent.onPress(note)
        }

        func keyboardView(_ view: PianoKeyboardView, didRelease note: PianoNote) {
            parent.onRelease(note)
        }
    }
}
