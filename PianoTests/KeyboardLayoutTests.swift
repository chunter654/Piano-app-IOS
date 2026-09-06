import CoreGraphics
import XCTest
@testable import Piano

final class KeyboardLayoutTests: XCTestCase {

    /// A portrait keyboard area: narrow and tall.
    private let bounds = CGRect(x: 0, y: 0, width: 370, height: 680)
    private let visible = KeyboardRangeController.visibleWhiteKeys

    private func frames(at position: Double) -> [KeyFrame] {
        KeyboardLayout.frames(position: position, visibleWhiteKeys: visible, in: bounds)
    }

    // MARK: - Shape of the result

    func testTheWholePianoIsLaidOut() {
        let all = frames(at: 16)
        XCTAssertEqual(all.count, 88)
        XCTAssertEqual(Set(all.map(\.note.midi)), Set(21...108))
    }

    func testWhiteKeysComeBeforeBlackKeysSoBlackKeysDrawOnTop() {
        let all = frames(at: 16)
        let firstBlack = all.firstIndex(where: \.isBlack)
        let lastWhite = all.lastIndex(where: { !$0.isBlack })
        XCTAssertNotNil(firstBlack)
        XCTAssertNotNil(lastWhite)
        XCTAssertGreaterThan(firstBlack!, lastWhite!)
    }

    // MARK: - The property that makes scrolling smooth

    /// Moving the viewport must translate every key by the same amount. If keys
    /// changed size or moved relative to each other, the keyboard would re-flow
    /// as it scrolled, which is what made the old range control feel stepped.
    func testScrollingTranslatesEveryKeyEqually() {
        let thickness = bounds.height / CGFloat(visible)
        for delta in [0.05, 0.5, 1.0, 3.25, 11.0] {
            let base = frames(at: 10)
            let moved = frames(at: 10 + delta)
            XCTAssertEqual(base.count, moved.count)
            for (a, b) in zip(base, moved) {
                XCTAssertEqual(a.note, b.note)
                XCTAssertEqual(a.frame.height, b.frame.height, accuracy: 0.0001,
                               "\(a.note.name) changed size while scrolling")
                XCTAssertEqual(a.frame.width, b.frame.width, accuracy: 0.0001)
                XCTAssertEqual(b.frame.minY, a.frame.minY - CGFloat(delta) * thickness,
                               accuracy: 0.001,
                               "\(a.note.name) did not translate with the scroll")
            }
        }
    }

    func testKeySizesDoNotDependOnPosition() {
        let thickness = bounds.height / CGFloat(visible)
        for position in stride(from: 0.0, through: KeyboardRangeController.maxPosition, by: 0.5) {
            for frame in frames(at: position) {
                if frame.isBlack {
                    XCTAssertEqual(frame.frame.height,
                                   thickness * KeyboardLayout.blackThicknessRatio,
                                   accuracy: 0.0001)
                } else {
                    XCTAssertEqual(frame.frame.height, thickness, accuracy: 0.0001)
                }
            }
        }
    }

    // MARK: - Orientation

    func testPitchAscendsDownTheScreen() {
        let sorted = frames(at: 16).sorted { $0.note.midi < $1.note.midi }
        for (lower, higher) in zip(sorted, sorted.dropFirst()) {
            XCTAssertLessThan(lower.frame.midY, higher.frame.midY,
                              "\(lower.note.name) should sit above \(higher.note.name)")
        }
    }

    func testWhiteKeysRunTheFullWidthAndAccidentalsReachInFromTheRight() {
        for frame in frames(at: 16) {
            XCTAssertEqual(frame.frame.maxX, bounds.maxX, accuracy: 0.001)
            if frame.isBlack {
                XCTAssertGreaterThan(frame.frame.minX, bounds.minX)
            } else {
                XCTAssertEqual(frame.frame.minX, bounds.minX, accuracy: 0.001)
            }
        }
    }

    // MARK: - Musical correctness

    func testWhiteKeysTileThePianoWithoutGapsOrOverlap() {
        let whites = frames(at: 16).filter { !$0.isBlack }.sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(whites.count, 52, "an 88-key piano has 52 white keys")
        for (upper, lower) in zip(whites, whites.dropFirst()) {
            XCTAssertEqual(upper.frame.maxY, lower.frame.minY, accuracy: 0.001)
        }
    }

    func testEachAccidentalSitsBetweenItsTwoNeighbouringNaturals() {
        let byNote = Dictionary(uniqueKeysWithValues: frames(at: 16).map { ($0.note.midi, $0.frame) })
        for (midi, frame) in byNote where PianoNote(midi: midi).isBlack {
            if let below = byNote[midi - 1] {
                XCTAssertGreaterThan(frame.midY, below.midY)
                XCTAssertGreaterThan(frame.maxY, below.minY, "should overlap its lower neighbour")
            }
            if let above = byNote[midi + 1] {
                XCTAssertLessThan(frame.midY, above.midY)
                XCTAssertLessThan(frame.minY, above.maxY, "should overlap its upper neighbour")
            }
        }
    }

    // MARK: - The viewport

    func testDefaultPositionShowsExactlyC3ToC5() {
        let all = frames(at: KeyboardRangeController.defaultPosition)
        let whollyVisible = all.filter {
            $0.frame.minY >= bounds.minY - 0.001 && $0.frame.maxY <= bounds.maxY + 0.001
        }
        XCTAssertEqual(whollyVisible.count, 25, "two octaves, as the app has always shown")
        XCTAssertEqual(whollyVisible.map(\.note.midi).min(), 48, "C3")
        XCTAssertEqual(whollyVisible.map(\.note.midi).max(), 72, "C5")

        let c3 = all.first { $0.note.midi == 48 }!
        let c5 = all.first { $0.note.midi == 72 }!
        XCTAssertEqual(c3.frame.minY, bounds.minY, accuracy: 0.001, "C3 should meet the top edge")
        XCTAssertEqual(c5.frame.maxY, bounds.maxY, accuracy: 0.001, "C5 should meet the bottom edge")
    }

    func testTheEndsOfThePianoLineUpWithTheEndsOfTheTravel() {
        let lowest = frames(at: 0).first { $0.note.midi == PianoNote.lowest.midi }!
        XCTAssertEqual(lowest.frame.minY, bounds.minY, accuracy: 0.001, "A0 at the top of the travel")

        let highest = frames(at: KeyboardRangeController.maxPosition)
            .first { $0.note.midi == PianoNote.highest.midi }!
        XCTAssertEqual(highest.frame.maxY, bounds.maxY, accuracy: 0.001, "C8 at the bottom of the travel")
    }

    func testAboutTwoOctavesStayVisibleWhereverTheViewportIs() {
        for position in stride(from: 0.0, through: KeyboardRangeController.maxPosition, by: 0.25) {
            let onScreen = frames(at: position).filter {
                $0.frame.maxY > bounds.minY && $0.frame.minY < bounds.maxY
            }
            XCTAssertGreaterThanOrEqual(onScreen.count, 24, "too few keys at \(position)")
            XCTAssertLessThanOrEqual(onScreen.count, 28, "too many keys at \(position)")
        }
    }

    func testWhiteKeysStayLargeEnoughToPlay() {
        let thickness = bounds.height / CGFloat(visible)
        XCTAssertGreaterThan(thickness, 40)
    }

    func testDegenerateBoundsProduceNoKeys() {
        XCTAssertTrue(KeyboardLayout.frames(position: 16, visibleWhiteKeys: visible, in: .zero).isEmpty)
        XCTAssertTrue(KeyboardLayout.frames(position: 16, visibleWhiteKeys: 0, in: bounds).isEmpty)
    }
}
