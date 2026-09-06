import XCTest
@testable import Piano

final class PianoNoteTests: XCTestCase {

    func testReferencePitches() {
        XCTAssertEqual(PianoNote(midi: 48).name, "C3")
        XCTAssertEqual(PianoNote(midi: 60).name, "C4")
        XCTAssertEqual(PianoNote(midi: 72).name, "C5")
        XCTAssertEqual(PianoNote(midi: 21).name, "A0")
        XCTAssertEqual(PianoNote(midi: 108).name, "C8")
    }

    func testAccidentalsUseSharpsThroughout() {
        XCTAssertEqual(PianoNote(midi: 49).name, "C♯3")
        XCTAssertEqual(PianoNote(midi: 51).name, "D♯3")
        XCTAssertEqual(PianoNote(midi: 54).name, "F♯3")
        XCTAssertEqual(PianoNote(midi: 56).name, "G♯3")
        XCTAssertEqual(PianoNote(midi: 58).name, "A♯3")
        XCTAssertFalse(PianoNote.pitchClassNames.contains { $0.contains("♭") })
    }

    func testOctaveBoundaryFallsOnC() {
        XCTAssertEqual(PianoNote(midi: 59).name, "B3")
        XCTAssertEqual(PianoNote(midi: 60).name, "C4")
    }

    func testBlackKeysAreTheFiveAccidentals() {
        let blackPitchClasses = (21...108)
            .map(PianoNote.init(midi:))
            .filter(\.isBlack)
            .map(\.pitchClass)
        XCTAssertEqual(Set(blackPitchClasses), [1, 3, 6, 8, 10])
    }

    func testEveryNoteIsEitherBlackOrWhite() {
        for midi in 21...108 {
            let note = PianoNote(midi: midi)
            XCTAssertNotEqual(note.isBlack, note.isWhite)
        }
    }

    func testSpokenNameAvoidsTheSharpGlyph() {
        XCTAssertEqual(PianoNote(midi: 49).spokenName, "C sharp 3")
        XCTAssertEqual(PianoNote(midi: 48).spokenName, "C 3")
    }

    func testTransposition() {
        XCTAssertEqual(PianoNote(midi: 48).transposed(by: 24).midi, 72)
        XCTAssertEqual(PianoNote(midi: 48).transposed(by: -1).name, "B2")
    }
}
