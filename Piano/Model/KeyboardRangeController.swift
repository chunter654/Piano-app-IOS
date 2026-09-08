import Combine
import Foundation

/// Owns where the viewport sits on the piano.
///
/// The position is continuous, measured in white keys from A0, so dragging the
/// slider slides the instrument past the screen instead of re-flowing a fixed
/// number of notes a semitone at a time. Fractional positions are the point:
/// they are what makes the movement smooth rather than stepped.
final class KeyboardRangeController: ObservableObject {

    /// White keys on an 88-key piano, A0 through C8.
    static let whiteKeyCount = 52

    /// How many white keys the single column shows. Not a constant: pinching
    /// the range bar zooms the keyboard, and this is what changes.
    static let defaultVisibleWhiteKeys: Double = 15   // the span of C3 to C5

    /// Closer in than this and barely an octave is reachable; wider out and the
    /// keys are narrower than a fingertip and stop being playable.
    static let minVisibleWhiteKeys: Double = 8
    static let maxVisibleWhiteKeys: Double = 32

    /// Semitones the stacked arrangement shows: two whole octaves.
    static let stackedSpan = KeyboardLayout.semitonesPerOctave * 2

    /// The stacked arrangement is anchored on a starting note rather than
    /// scrolled, so it has its own limits.
    static let minStartNote = PianoNote.lowest.midi                       // A0
    static let maxStartNote = PianoNote.highest.midi - stackedSpan + 1    // C#6
    static let defaultStartNote = 48                                      // C3

    /// The stacked arrangement moves an octave at a time, so it only ever rests
    /// on a C. Those are the positions where two whole octaves still fit on the
    /// piano: C1 through C6.
    static let octaveStarts: [Int] = stride(from: 0, through: 127, by: 12)
        .filter { $0 >= minStartNote && $0 <= maxStartNote }

    /// The nearest octave position to an arbitrary note.
    static func nearestOctaveStart(to note: Int) -> Int {
        octaveStarts.min(by: { abs($0 - note) < abs($1 - note) }) ?? defaultStartNote
    }

    /// Position 0 puts A0 at the top; this is as far down the piano as the
    /// single column can travel before C8 reaches the bottom. It shrinks as the
    /// keyboard zooms out, because more keys on screen leaves less to scroll.
    static func maxPosition(showing visibleWhiteKeys: Double) -> Double {
        Double(whiteKeyCount) - visibleWhiteKeys
    }

    var maxPosition: Double { Self.maxPosition(showing: visibleWhiteKeys) }

    /// C3 is the seventeenth white key, counting A0 as the first, so a fresh
    /// install opens on C3 to C5.
    static let defaultPosition: Double = 16

    /// Where the viewport was left last time. Absent until the user first moves
    /// the keyboard, which is what makes a new install start at C3 to C5.
    private static let storageKey = "keyboard.viewportPosition"
    private static let modeKey = "keyboard.layoutMode"
    private static let startNoteKey = "keyboard.startNote"
    private static let zoomKey = "keyboard.visibleWhiteKeys"

    @Published private(set) var position: Double

    /// How much of the piano is on screen. Drives both the key sizes and
    /// the size of the slider thumb, which is why the thumb shrinks as you
    /// zoom in: it is a true measure of the fraction in view.
    @Published private(set) var visibleWhiteKeys: Double

    /// Which arrangement the keyboard is in. Remembered along with the position.
    @Published private(set) var mode: KeyboardLayoutMode

    /// Where the stacked arrangement starts, as a MIDI note. Kept separately
    /// from `position` because the two arrangements move differently: one
    /// scrolls continuously, the other steps a semitone at a time.
    @Published private(set) var startNote: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Held locally as well: Swift will not let the stored property be read
        // back until every property has a value.
        let resolvedMode = (defaults.string(forKey: Self.modeKey))
            .flatMap(KeyboardLayoutMode.init(rawValue:)) ?? .single
        mode = resolvedMode
        // `double(forKey:)` cannot tell a missing key from a stored zero, and
        // zero is a real position — A0 at the top of the screen — so the raw
        // object has to be read instead. A stored value is still clamped: the
        // reachable range depends on constants that could change in a later
        // version, and a rogue value must not strand the keyboard off the piano.
        // Held locally for the same reason as the mode above: a stored property
        // cannot be read back until every one of them has a value, and the
        // travel below is derived from this one.
        let resolvedZoom: Double
        if let savedZoom = defaults.object(forKey: Self.zoomKey) as? Double, savedZoom.isFinite {
            resolvedZoom = min(max(savedZoom, Self.minVisibleWhiteKeys),
                               Self.maxVisibleWhiteKeys)
        } else {
            resolvedZoom = Self.defaultVisibleWhiteKeys
        }
        visibleWhiteKeys = resolvedZoom
        let travel = Self.maxPosition(showing: resolvedZoom)
        if let saved = defaults.object(forKey: Self.storageKey) as? Double, saved.isFinite {
            position = min(max(saved, 0), travel)
        } else {
            position = min(Self.defaultPosition, travel)
        }

        if let savedStart = defaults.object(forKey: Self.startNoteKey) as? Int {
            startNote = Self.nearestOctaveStart(to: savedStart)
        } else {
            startNote = Self.defaultStartNote
        }
    }

    /// Switches arrangement, carrying your place on the piano across.
    ///
    /// The two arrangements measure position differently, so the value has to be
    /// translated. It lands on the nearest whole key rather than exactly where
    /// you were, which is the closest a continuous scroll and a semitone-stepped
    /// window can meet.
    func toggleMode() {
        switch mode {
        case .single:
            let whiteIndex = min(max(Int(position.rounded()), 0), Self.whiteKeyCount - 1)
            setStartNote(KeyboardLayout.whiteMidis[whiteIndex])
        case .twoRow:
            let whiteIndex = KeyboardLayout.whitesBelow(PianoNote(midi: startNote))
            setPosition(Double(whiteIndex))
        }
        mode = mode.other
        defaults.set(mode.rawValue, forKey: Self.modeKey)
    }

    // MARK: - Stacked arrangement

    var canStepDown: Bool { startNote > (Self.octaveStarts.first ?? startNote) }
    var canStepUp: Bool { startNote < (Self.octaveStarts.last ?? startNote) }

    var lowestStackedNote: PianoNote { PianoNote(midi: startNote) }
    var highestStackedNote: PianoNote { PianoNote(midi: startNote + Self.stackedSpan - 1) }

    /// "C3 — B4"
    var stackedDisplayName: String {
        "\(lowestStackedNote.name) — \(highestStackedNote.name)"
    }

    var stackedSpokenName: String {
        "\(lowestStackedNote.spokenName) to \(highestStackedNote.spokenName)"
    }

    /// Always lands on an octave position, wherever it is asked to go.
    @discardableResult
    func setStartNote(_ value: Int) -> Bool {
        let snapped = Self.nearestOctaveStart(to: value)
        guard snapped != startNote else { return false }
        startNote = snapped
        defaults.set(snapped, forKey: Self.startNoteKey)
        return true
    }

    /// One octave at a time, which is what the arrows do.
    @discardableResult
    func stepOctave(_ delta: Int) -> Bool {
        guard let index = Self.octaveStarts.firstIndex(of: startNote) else {
            return setStartNote(startNote)
        }
        let target = index + delta
        guard Self.octaveStarts.indices.contains(target) else { return false }
        return setStartNote(Self.octaveStarts[target])
    }

    /// How far along the piano the viewport is, 0 to 1. Drives the slider.
    var progress: Double {
        guard maxPosition > 0 else { return 0 }
        return position / maxPosition
    }

    /// The lowest and highest notes currently on screen, rounded to whole keys.
    var visibleNotes: (low: PianoNote, high: PianoNote) {
        let first = Int(position.rounded(.down))
        let last = Int((position + visibleWhiteKeys).rounded(.up)) - 1
        let lowIndex = min(max(first, 0), Self.whiteKeyCount - 1)
        let highIndex = min(max(last, 0), Self.whiteKeyCount - 1)
        return (PianoNote(midi: KeyboardLayout.whiteMidis[lowIndex]),
                PianoNote(midi: KeyboardLayout.whiteMidis[highIndex]))
    }

    /// "C3 to C5", for VoiceOver.
    var spokenName: String {
        let notes = visibleNotes
        return "\(notes.low.spokenName) to \(notes.high.spokenName)"
    }

    var canMoveDown: Bool { position > 0 }
    var canMoveUp: Bool { position < maxPosition }

    /// Moves the viewport, clamped to the piano, and remembers where it landed.
    /// Returns whether it moved.
    @discardableResult
    func setPosition(_ value: Double) -> Bool {
        // Clamping a NaN is not meaningful, so reject it before comparing.
        guard value.isFinite else { return false }
        let clamped = min(max(value, 0), maxPosition)
        guard abs(clamped - position) > 1e-9 else { return false }
        position = clamped
        defaults.set(clamped, forKey: Self.storageKey)
        return true
    }

    /// Changes how much of the piano is on screen, holding the middle of the
    /// view still. Zooming about the centre keeps the keys under your hand
    /// where they were; anchoring anywhere else slides the instrument sideways
    /// while you are only trying to change its size.
    @discardableResult
    func setVisibleWhiteKeys(_ value: Double) -> Bool {
        guard value.isFinite else { return false }
        let clamped = min(max(value, Self.minVisibleWhiteKeys), Self.maxVisibleWhiteKeys)
        guard abs(clamped - visibleWhiteKeys) > 1e-9 else { return false }

        let centre = position + visibleWhiteKeys / 2
        visibleWhiteKeys = clamped
        defaults.set(clamped, forKey: Self.zoomKey)
        // The travel has changed underneath the position, so this both recentres
        // and pulls it back inside the piano.
        setPosition(centre - clamped / 2)
        return true
    }

    /// One whole key at a time, for VoiceOver and anything else that needs a
    /// discrete step rather than a drag.
    @discardableResult
    func step(by whiteKeys: Int) -> Bool {
        setPosition((position.rounded() + Double(whiteKeys)))
    }
}
