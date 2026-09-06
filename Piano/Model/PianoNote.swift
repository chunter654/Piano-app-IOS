import Foundation

/// A single pitch, identified by its MIDI note number.
///
/// Everything the app knows about a key — its name, its octave, whether it is
/// drawn black or white — is derived from the MIDI number, so the keyboard stays
/// musically correct no matter which chromatic note a range happens to start on.
struct PianoNote: Hashable, Comparable, Identifiable {

    /// This app names accidentals with sharps everywhere. Never flats.
    static let pitchClassNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    private static let blackPitchClasses: Set<Int> = [1, 3, 6, 8, 10]

    /// The extremes of an 88-key acoustic piano, which is also the range this
    /// app allows the user to reach: A0 through C8.
    static let lowest = PianoNote(midi: 21)
    static let highest = PianoNote(midi: 108)

    let midi: Int

    var id: Int { midi }

    init(midi: Int) {
        self.midi = midi
    }

    /// 0 = C, 1 = C♯ … 11 = B.
    var pitchClass: Int {
        let raw = midi % 12
        return raw < 0 ? raw + 12 : raw
    }

    /// Scientific pitch notation, in which MIDI 60 is C4.
    var octave: Int {
        Int((Double(midi) / 12).rounded(.down)) - 1
    }

    var isBlack: Bool { Self.blackPitchClasses.contains(pitchClass) }
    var isWhite: Bool { !isBlack }

    /// "C", "C♯", "D" …
    var pitchName: String { Self.pitchClassNames[pitchClass] }

    /// "C3", "C♯3", "B4" …
    var name: String { "\(pitchName)\(octave)" }

    /// Spoken form, so VoiceOver says "C sharp 3" rather than reading the glyph.
    var spokenName: String {
        isBlack ? "\(pitchName.dropLast()) sharp \(octave)" : "\(pitchName) \(octave)"
    }

    func transposed(by semitones: Int) -> PianoNote {
        PianoNote(midi: midi + semitones)
    }

    static func < (lhs: PianoNote, rhs: PianoNote) -> Bool { lhs.midi < rhs.midi }
}
