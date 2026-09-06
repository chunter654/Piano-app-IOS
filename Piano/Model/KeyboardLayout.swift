import CoreGraphics

/// How the piano is arranged on screen.
enum KeyboardLayoutMode: String, CaseIterable {
    /// One continuous column, the piano turned a quarter turn clockwise: pitch
    /// runs down the screen and key fronts face left.
    case single

    /// Two stacked rows of conventional keyboard, the upper octave continuing
    /// on the lower row. Key fronts face down.
    case twoRow

    var other: KeyboardLayoutMode { self == .single ? .twoRow : .single }
}

/// One key, positioned.

struct KeyFrame: Equatable {
    let note: PianoNote
    let frame: CGRect

    var isBlack: Bool { note.isBlack }
}

/// Turns the piano into geometry.
///
/// The whole 88-key instrument is laid out at a fixed key size and the viewport
/// slides along it, rather than a fixed number of notes being re-fitted into the
/// screen. Keys therefore never change size or shuffle position as the range
/// moves: the piano slides past, the way it would if you moved along a real one.
///
/// The keyboard is a real piano turned a quarter turn clockwise: pitch runs down
/// the screen, and the front edge of every key faces left, so accidentals reach
/// in from the right, which is the back of the instrument.
enum KeyboardLayout {

    /// How much of a white key's span along the pitch axis an accidental covers.
    /// A real piano is roughly 13.7 mm against 23.5 mm.
    static let blackThicknessRatio: CGFloat = 0.62

    /// How far an accidental reaches from the back of the keyboard towards the
    /// front, as a fraction of a white key's full length.
    static let blackLengthRatio: CGFloat = 0.63

    /// How far each accidental sits from the seam between its neighbouring white
    /// keys, in white-key thicknesses. On a real piano the groups of two and
    /// three are spread apart rather than centred on the seam. Negative moves
    /// towards the lower neighbour, which here means up the screen.
    private static let blackKeyOffsets: [Int: CGFloat] = [
        1: -0.075,   // C♯
        3:  0.075,   // D♯
        6: -0.095,   // F♯
        8:  0.0,     // G♯
        10: 0.095,   // A♯
    ]

    /// Every note on the piano, A0 through C8.
    static let allNotes: [PianoNote] =
        (PianoNote.lowest.midi...PianoNote.highest.midi).map(PianoNote.init(midi:))

    /// The MIDI number of each white key, indexed by its position among the
    /// whites. `whiteMidis[0]` is A0 and `whiteMidis[51]` is C8.
    static let whiteMidis: [Int] = allNotes.filter(\.isWhite).map(\.midi)

    /// How many white keys sit below a given note. For a white key this is its
    /// own index among the whites; for an accidental it is the index of the
    /// white key immediately above it, which is where its seam falls.
    private static let whitesBelowTable: [Int] = {
        var counts: [Int] = []
        counts.reserveCapacity(allNotes.count)
        var seen = 0
        for note in allNotes {
            counts.append(seen)
            if note.isWhite { seen += 1 }
        }
        return counts
    }()

    static func whitesBelow(_ note: PianoNote) -> Int {
        let index = note.midi - PianoNote.lowest.midi
        guard whitesBelowTable.indices.contains(index) else { return 0 }
        return whitesBelowTable[index]
    }

    /// White keys shown per row in two-row mode. One octave each, so the rows
    /// divide the keyboard where a player would expect.
    static let whiteKeysPerRow = 7

    /// Semitones in the window each stacked row shows.
    static let semitonesPerOctave = 12

    /// Gap between the two rows.
    static let rowSpacing: CGFloat = 12


    /// Two stacked rows of exactly one octave each, the lower octave on top.
    ///
    /// This is the older arrangement: a fixed window of 24 semitones re-fitted
    /// into the screen, anchored on a starting MIDI note rather than scrolled.
    /// Moving it a semitone re-flows both rows. An octave always contains seven
    /// naturals whatever note it starts on, so the keys keep their size; what
    /// changes is which of them are black.
    static func twoRowFrames(startNote: Int, in bounds: CGRect) -> [KeyFrame] {
        guard bounds.width > 0, bounds.height > 0 else { return [] }
        let rowHeight = (bounds.height - rowSpacing) / 2
        guard rowHeight > 0 else { return [] }

        // The lower octave sits on top and the upper one below, so the pair
        // reads like two lines of text and pitch rises down the screen, as it
        // does in the single column.
        let lower = CGRect(x: bounds.minX, y: bounds.minY,
                           width: bounds.width, height: rowHeight)
        let upper = CGRect(x: bounds.minX, y: bounds.minY + rowHeight + rowSpacing,
                           width: bounds.width, height: rowHeight)

        let lowerKeys = rowFrames(startNote: startNote, in: lower)
        let upperKeys = rowFrames(startNote: startNote + semitonesPerOctave, in: upper)

        // Naturals first across both rows, so accidentals draw over them.
        return lowerKeys.filter { !$0.isBlack } + upperKeys.filter { !$0.isBlack }
             + lowerKeys.filter { $0.isBlack } + upperKeys.filter { $0.isBlack }
    }

    /// One octave laid out across `rect` as a conventional keyboard.
    private static func rowFrames(startNote: Int, in rect: CGRect) -> [KeyFrame] {
        let notes = (0..<semitonesPerOctave).map { PianoNote(midi: startNote + $0) }
        let whiteCount = notes.filter(\.isWhite).count
        guard whiteCount > 0, let first = notes.first, let last = notes.last else { return [] }

        // A row that starts or ends on an accidental needs half a natural of
        // margin, or that key would be cut off by the edge of the row.
        let leadingPad: CGFloat = first.isBlack ? 0.5 : 0
        let trailingPad: CGFloat = last.isBlack ? 0.5 : 0
        let whiteWidth = rect.width / (CGFloat(whiteCount) + leadingPad + trailingPad)
        let originX = rect.minX + leadingPad * whiteWidth
        let blackWidth = whiteWidth * blackThicknessRatio
        let blackHeight = rect.height * blackLengthRatio

        var result: [KeyFrame] = []
        var whiteIndex = 0
        for note in notes where note.isWhite {
            result.append(KeyFrame(note: note,
                                   frame: CGRect(x: originX + CGFloat(whiteIndex) * whiteWidth,
                                                 y: rect.minY,
                                                 width: whiteWidth,
                                                 height: rect.height)))
            whiteIndex += 1
        }

        whiteIndex = 0
        for note in notes {
            guard note.isBlack else { whiteIndex += 1; continue }
            let seam = originX + CGFloat(whiteIndex) * whiteWidth
            let nudge = (blackKeyOffsets[note.pitchClass] ?? 0) * whiteWidth
            result.append(KeyFrame(note: note,
                                   frame: CGRect(x: seam - blackWidth / 2 + nudge,
                                                 y: rect.minY,
                                                 width: blackWidth,
                                                 height: blackHeight)))
        }
        return result
    }

    /// Lays the whole piano into `bounds`, scrolled to `position`.
    ///
    /// `position` is measured in white keys from A0, and may be fractional: it
    /// is the white-key index sitting at the top edge of the viewport. Keys
    /// outside the viewport are still returned, with frames above or below it,
    /// so the caller can keep one stable layer per key.
    ///
    /// White keys come first in the result and accidentals after them, which is
    /// both the drawing order and the reverse of the hit-testing order, so a
    /// touch on the overlap always resolves to the accidental.
    static func frames(position: Double, visibleWhiteKeys: Double, in bounds: CGRect) -> [KeyFrame] {
        guard bounds.width > 0, bounds.height > 0, visibleWhiteKeys > 0 else { return [] }

        let whiteThickness = bounds.height / CGFloat(visibleWhiteKeys)
        let originY = bounds.minY - CGFloat(position) * whiteThickness
        let blackThickness = whiteThickness * blackThicknessRatio
        let blackLength = bounds.width * blackLengthRatio

        var result: [KeyFrame] = []
        result.reserveCapacity(allNotes.count)

        for note in allNotes where note.isWhite {
            let y = originY + CGFloat(whitesBelow(note)) * whiteThickness
            result.append(KeyFrame(note: note,
                                   frame: CGRect(x: bounds.minX,
                                                 y: y,
                                                 width: bounds.width,
                                                 height: whiteThickness)))
        }

        for note in allNotes where note.isBlack {
            // The seam is the near edge of the white key above this accidental,
            // which is where it belongs on a real keyboard.
            let seam = originY + CGFloat(whitesBelow(note)) * whiteThickness
            let nudge = (blackKeyOffsets[note.pitchClass] ?? 0) * whiteThickness
            result.append(KeyFrame(note: note,
                                   frame: CGRect(x: bounds.maxX - blackLength,
                                                 y: seam - blackThickness / 2 + nudge,
                                                 width: blackLength,
                                                 height: blackThickness)))
        }

        return result
    }
}
