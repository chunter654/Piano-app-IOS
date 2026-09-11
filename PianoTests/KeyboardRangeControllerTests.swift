import XCTest
@testable import Piano

final class KeyboardRangeControllerTests: XCTestCase {

    /// The travel at the default zoom, which is what these tests assume.
    private var maxPosition: Double {
        KeyboardRangeController.maxPosition(showing: KeyboardRangeController.defaultVisibleWhiteKeys)
    }

    /// Each test gets its own storage, so nothing leaks between them or into the
    /// real app's saved position.
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "KeyboardRangeControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeController() -> KeyboardRangeController {
        KeyboardRangeController(defaults: defaults)
    }

    // MARK: - Opening position

    func testAFreshInstallOpensOnTheStackedRows() {
        let range = makeController()
        XCTAssertEqual(range.mode, KeyboardRangeController.defaultMode)
        XCTAssertEqual(range.mode, .twoRow)
    }

    func testASavedArrangementBeatsTheDefault() {
        defaults.set(KeyboardLayoutMode.single.rawValue, forKey: "keyboard.layoutMode")
        XCTAssertEqual(makeController().mode, .single)
    }

    func testAFreshInstallOpensOnC3ToC5() {
        let range = makeController()
        XCTAssertEqual(range.position, 16, accuracy: 0.0001)
        XCTAssertEqual(range.visibleNotes.low.name, "C3")
        XCTAssertEqual(range.visibleNotes.high.name, "C5")
    }

    func testReopeningRestoresWhereYouWere() {
        let first = makeController()
        first.setPosition(23.5)

        let second = makeController()
        XCTAssertEqual(second.position, 23.5, accuracy: 0.0001)
    }

    /// Zero is a real position — A0 at the top — so it must not be mistaken for
    /// "nothing saved" and silently replaced by the default.
    func testASavedPositionOfZeroIsHonoured() {
        let first = makeController()
        first.setPosition(0)

        let second = makeController()
        XCTAssertEqual(second.position, 0, accuracy: 0.0001)
        XCTAssertEqual(second.visibleNotes.low.name, "A0")
    }

    func testASavedPositionBeyondThePianoIsClamped() {
        defaults.set(9_999.0, forKey: "keyboard.viewportPosition")
        XCTAssertEqual(makeController().position, maxPosition, accuracy: 0.0001)

        defaults.set(-9_999.0, forKey: "keyboard.viewportPosition")
        XCTAssertEqual(makeController().position, 0, accuracy: 0.0001)
    }

    func testNonsenseInStorageFallsBackToTheDefault() {
        defaults.set(Double.nan, forKey: "keyboard.viewportPosition")
        XCTAssertEqual(makeController().position, KeyboardRangeController.defaultPosition, accuracy: 0.0001)

        defaults.set("not a number", forKey: "keyboard.viewportPosition")
        XCTAssertEqual(makeController().position, KeyboardRangeController.defaultPosition, accuracy: 0.0001)
    }

    func testARejectedMoveIsNotSaved() {
        let first = makeController()
        first.setPosition(20)
        XCTAssertFalse(first.setPosition(.nan))

        let second = makeController()
        XCTAssertEqual(second.position, 20, accuracy: 0.0001)
    }

    // MARK: - Movement

    func testPositionIsContinuous() {
        let range = makeController()
        XCTAssertTrue(range.setPosition(16.25))
        XCTAssertEqual(range.position, 16.25, accuracy: 0.0001)
        XCTAssertTrue(range.setPosition(16.3))
        XCTAssertEqual(range.position, 16.3, accuracy: 0.0001)
    }

    func testSettingTheSamePositionReportsNoMovement() {
        let range = makeController()
        XCTAssertFalse(range.setPosition(16))
    }

    func testTravelIsClampedToThePiano() {
        let range = makeController()
        range.setPosition(-50)
        XCTAssertEqual(range.position, 0, accuracy: 0.0001)
        XCTAssertFalse(range.canMoveDown)
        XCTAssertEqual(range.visibleNotes.low.name, "A0")

        range.setPosition(500)
        XCTAssertEqual(range.position, maxPosition, accuracy: 0.0001)
        XCTAssertFalse(range.canMoveUp)
        XCTAssertEqual(range.visibleNotes.high.name, "C8")
    }

    func testProgressSpansZeroToOne() {
        let range = makeController()
        range.setPosition(0)
        XCTAssertEqual(range.progress, 0, accuracy: 0.0001)
        range.setPosition(maxPosition)
        XCTAssertEqual(range.progress, 1, accuracy: 0.0001)
    }

    func testSteppingMovesOneWholeKey() {
        let range = makeController()
        range.setPosition(16.4)
        range.step(by: 1)
        XCTAssertEqual(range.position, 17, accuracy: 0.0001)
        range.step(by: -1)
        XCTAssertEqual(range.position, 16, accuracy: 0.0001)
    }

    func testSteppingStopsAtTheEnds() {
        let range = makeController()
        range.setPosition(0)
        XCTAssertFalse(range.step(by: -1))
        range.setPosition(maxPosition)
        XCTAssertFalse(range.step(by: 1))
    }

    func testNoReachablePositionLeavesThePiano() {
        let range = makeController()
        for tenth in 0...Int(maxPosition * 10) {
            range.setPosition(Double(tenth) / 10)
            let notes = range.visibleNotes
            XCTAssertGreaterThanOrEqual(notes.low.midi, PianoNote.lowest.midi)
            XCTAssertLessThanOrEqual(notes.high.midi, PianoNote.highest.midi)
        }
    }
}

// MARK: - Zoom

extension KeyboardRangeControllerTests {

    func testZoomIsHeldWithinItsLimits() {
        let range = makeController()

        range.setVisibleWhiteKeys(1)
        XCTAssertEqual(range.visibleWhiteKeys,
                       KeyboardRangeController.minVisibleWhiteKeys, accuracy: 0.0001)

        range.setVisibleWhiteKeys(1_000)
        XCTAssertEqual(range.visibleWhiteKeys,
                       KeyboardRangeController.maxVisibleWhiteKeys, accuracy: 0.0001)
    }

    func testNonsenseZoomIsRejectedRatherThanStored() {
        let range = makeController()
        let before = range.visibleWhiteKeys
        XCTAssertFalse(range.setVisibleWhiteKeys(.nan))
        XCTAssertEqual(range.visibleWhiteKeys, before, accuracy: 0.0001)
    }

    /// The keys under your hand should stay roughly where they were, which is
    /// what makes zooming feel like changing size rather than moving house.
    func testZoomingHoldsTheMiddleOfTheViewStill() {
        let range = makeController()
        range.setPosition(20)
        let centreBefore = range.position + range.visibleWhiteKeys / 2

        range.setVisibleWhiteKeys(10)
        XCTAssertEqual(range.position + range.visibleWhiteKeys / 2, centreBefore, accuracy: 0.0001)

        range.setVisibleWhiteKeys(24)
        XCTAssertEqual(range.position + range.visibleWhiteKeys / 2, centreBefore, accuracy: 0.0001)
    }

    /// Widening the view at the bottom of the piano leaves less room to scroll,
    /// so the position has to come back rather than hang off the end.
    func testZoomingOutAtTheEndPullsTheViewBackOntoThePiano() {
        let range = makeController()
        range.setPosition(range.maxPosition)
        XCTAssertEqual(range.position, range.maxPosition, accuracy: 0.0001)

        range.setVisibleWhiteKeys(KeyboardRangeController.maxVisibleWhiteKeys)
        XCTAssertLessThanOrEqual(range.position, range.maxPosition + 0.0001)
        XCTAssertGreaterThanOrEqual(range.position, -0.0001)
    }

    func testTheWholePianoIsReachableAtEveryZoom() {
        for keys in stride(from: KeyboardRangeController.minVisibleWhiteKeys,
                           through: KeyboardRangeController.maxVisibleWhiteKeys, by: 1) {
            let range = makeController()
            range.setVisibleWhiteKeys(keys)

            range.setPosition(0)
            XCTAssertEqual(range.visibleNotes.low.name, "A0", "at \(keys) keys")

            range.setPosition(range.maxPosition)
            XCTAssertEqual(range.visibleNotes.high.name, "C8", "at \(keys) keys")
        }
    }

    func testZoomIsRememberedAcrossLaunches() {
        let first = makeController()
        first.setVisibleWhiteKeys(22)

        let second = makeController()
        XCTAssertEqual(second.visibleWhiteKeys, 22, accuracy: 0.0001)
    }

    /// A stored value from some future version with different limits must not
    /// strand the keyboard at a zoom this one cannot reach.
    func testAnOutOfRangeStoredZoomIsBroughtBackInside() {
        defaults.set(500.0, forKey: "keyboard.visibleWhiteKeys")
        let range = makeController()
        XCTAssertEqual(range.visibleWhiteKeys,
                       KeyboardRangeController.maxVisibleWhiteKeys, accuracy: 0.0001)
    }
}
