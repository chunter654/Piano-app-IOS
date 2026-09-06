import UIKit

protocol PianoKeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: PianoKeyboardView, didPress note: PianoNote)
    func keyboardView(_ view: PianoKeyboardView, didRelease note: PianoNote)
}

/// The playable surface: one continuous keyboard, every finger tracked
/// independently.
///
/// Touch handling lives here rather than on the individual keys so that a finger
/// can slide from one key to the next, and so that a touch which wanders off the
/// keyboard releases its note instead of stranding it.
final class PianoKeyboardView: UIView {

    weak var delegate: PianoKeyboardViewDelegate?

    /// Where the viewport sits on the piano, in white keys from A0. Fractional
    /// values are expected: this is what the slider drives.
    var position: Double = KeyboardRangeController.defaultPosition {
        didSet {
            guard position != oldValue else { return }
            // Keys slide rather than change identity, so nothing needs lifting
            // here: a finger stays on the key it is touching.
            setNeedsLayout()
            updateAccessibilityValue()
        }
    }

    /// Where the stacked arrangement starts, as a MIDI note.
    var startNote: Int = KeyboardRangeController.defaultStartNote {
        didSet {
            guard startNote != oldValue else { return }
            // The window re-flows, so every key becomes a different note and
            // nothing being held is under a finger any more.
            releaseAllKeys()
            setNeedsLayout()
            updateAccessibilityValue()
        }
    }

    /// Which arrangement the keyboard is in.
    var mode: KeyboardLayoutMode = .single {
        didSet {
            guard mode != oldValue else { return }
            // Every key is about to move somewhere unrelated, so nothing that
            // was being held is under a finger any more.
            releaseAllKeys()
            let orientation = Self.orientation(for: mode)
            for keyLayer in keyLayers {
                keyLayer.orientation = orientation
            }
            setNeedsLayout()
        }
    }

    private static func orientation(for mode: KeyboardLayoutMode) -> KeyOrientation {
        mode == .single ? .frontLeft : .frontBottom
    }

    private var keyLayers: [PianoKeyLayer] = []

    /// Which key each finger currently owns. A finger with no entry is either
    /// off the keyboard or has not landed on a key yet.
    private var touchedKeys: [ObjectIdentifier: PianoKeyLayer] = [:]

    /// How many fingers are holding each note, so that lifting one of two
    /// fingers from the same key does not cut the note off.
    private var holdCounts: [Int: Int] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
        // The piano is longer than the viewport, so the ends have to be cut off.
        layer.masksToBounds = true
        // Let VoiceOver pass touches straight through: an instrument is played
        // by touching it, not by selecting each key in turn.
        isAccessibilityElement = true
        accessibilityTraits = .allowsDirectInteraction
        accessibilityLabel = "Piano keyboard"
        updateAccessibilityValue()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let frames = keyFrames()
        syncLayers(to: frames)

        let scale = displayScale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (keyLayer, keyFrame) in zip(keyLayers, frames) {
            keyLayer.frame = keyFrame.frame
            keyLayer.updateGeometry(displayScale: scale)
        }
        CATransaction.commit()
    }

    private var displayScale: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? scale : 3
    }

    /// The whole piano, positioned so the viewport shows the current slice.
    /// Turning the keyboard on its side is what makes two octaves playable on a
    /// portrait phone: laid out across the screen each white key would be under
    /// 30 points wide, whereas down the screen they are comfortably over 40
    /// points tall.
    private func keyFrames() -> [KeyFrame] {
        guard bounds.width > 0, bounds.height > 0 else { return [] }
        switch mode {
        case .single:
            return KeyboardLayout.frames(position: position,
                                         visibleWhiteKeys: KeyboardRangeController.visibleWhiteKeys,
                                         in: bounds)
        case .twoRow:
            return KeyboardLayout.twoRowFrames(startNote: startNote, in: bounds)
        }
    }

    /// Builds one layer per key, once.
    ///
    /// Every key on the piano gets a layer and keeps it for the life of the
    /// view, so scrolling only moves frames around and never allocates. Naturals
    /// come first in `frames` and accidentals last, so accidentals sit at the
    /// higher sublayer indices and therefore draw on top.
    private func syncLayers(to frames: [KeyFrame]) {
        let orientation = Self.orientation(for: mode)
        guard keyLayers.count == frames.count else {
            releaseAllKeys()
            for keyLayer in keyLayers {
                keyLayer.removeFromSuperlayer()
            }
            keyLayers = frames.map { PianoKeyLayer(note: $0.note, orientation: orientation) }
            for keyLayer in keyLayers {
                layer.addSublayer(keyLayer)
            }
            return
        }

        // The stacked window re-flows a semitone at a time, so the same layers
        // take on different notes. Scrolling never gets here: there the keys
        // keep their identity and only move.
        guard zip(keyLayers, frames).contains(where: { $0.note != $1.note }) else { return }
        releaseAllKeys()
        for (keyLayer, keyFrame) in zip(keyLayers, frames) {
            keyLayer.note = keyFrame.note
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { updateTouch(touch) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { updateTouch(touch) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { endTouch(touch) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { endTouch(touch) }
    }

    /// Handles a finger landing and a finger moving. A finger that has crossed
    /// onto a different key lifts the old note and strikes the new one; a finger
    /// that has left the keyboard lifts without striking anything, and strikes
    /// again if it comes back.
    private func updateTouch(_ touch: UITouch) {
        let id = ObjectIdentifier(touch)
        let hit = key(at: touch.location(in: self))
        let current = touchedKeys[id]
        guard hit !== current else { return }

        if let current {
            lift(current)
        }
        if let hit {
            touchedKeys[id] = hit
            strike(hit)
        } else {
            touchedKeys.removeValue(forKey: id)
        }
    }

    private func endTouch(_ touch: UITouch) {
        guard let keyLayer = touchedKeys.removeValue(forKey: ObjectIdentifier(touch)) else { return }
        lift(keyLayer)
    }

    /// Black keys are last in `keyLayers` and therefore drawn on top, so walking
    /// backwards resolves a touch on the overlap to the black key.
    private func key(at point: CGPoint) -> PianoKeyLayer? {
        keyLayers.last(where: { $0.frame.contains(point) })
    }

    private func strike(_ keyLayer: PianoKeyLayer) {
        holdCounts[keyLayer.note.midi, default: 0] += 1
        keyLayer.isPressed = true
        delegate?.keyboardView(self, didPress: keyLayer.note)
    }

    private func lift(_ keyLayer: PianoKeyLayer) {
        let midi = keyLayer.note.midi
        let remaining = (holdCounts[midi] ?? 1) - 1
        guard remaining <= 0 else {
            holdCounts[midi] = remaining
            return
        }
        holdCounts.removeValue(forKey: midi)
        keyLayer.isPressed = false
        delegate?.keyboardView(self, didRelease: keyLayer.note)
    }

    /// Lifts every finger the view believes is down. Called on range changes,
    /// when the view leaves the screen, and when the app is backgrounded.
    func releaseAllKeys() {
        let held = Array(touchedKeys.values)
        touchedKeys.removeAll()
        for keyLayer in held { lift(keyLayer) }

        // Belt and braces: nothing should be left marked as held.
        holdCounts.removeAll()
        for keyLayer in keyLayers where keyLayer.isPressed {
            keyLayer.isPressed = false
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            releaseAllKeys()
        }
    }

    // MARK: - Accessibility

    private func updateAccessibilityValue() {
        guard mode == .single else {
            let low = PianoNote(midi: startNote)
            let high = PianoNote(midi: startNote + KeyboardRangeController.stackedSpan - 1)
            accessibilityValue = "\(low.spokenName) to \(high.spokenName)"
            return
        }
        let visible = KeyboardRangeController.visibleWhiteKeys
        let first = min(max(Int(position.rounded(.down)), 0), KeyboardLayout.whiteMidis.count - 1)
        let last = min(max(Int((position + visible).rounded(.up)) - 1, 0),
                       KeyboardLayout.whiteMidis.count - 1)
        let low = PianoNote(midi: KeyboardLayout.whiteMidis[first])
        let high = PianoNote(midi: KeyboardLayout.whiteMidis[last])
        accessibilityValue = "\(low.spokenName) to \(high.spokenName)"
    }
}
