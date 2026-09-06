import XCTest
@testable import Piano

final class KeyboardRangeControllerTests: XCTestCase {

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
        XCTAssertEqual(makeController().position, KeyboardRangeController.maxPosition, accuracy: 0.0001)

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
        XCTAssertEqual(range.position, KeyboardRangeController.maxPosition, accuracy: 0.0001)
        XCTAssertFalse(range.canMoveUp)
        XCTAssertEqual(range.visibleNotes.high.name, "C8")
    }

    func testProgressSpansZeroToOne() {
        let range = makeController()
        range.setPosition(0)
        XCTAssertEqual(range.progress, 0, accuracy: 0.0001)
        range.setPosition(KeyboardRangeController.maxPosition)
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
        range.setPosition(KeyboardRangeController.maxPosition)
        XCTAssertFalse(range.step(by: 1))
    }

    func testNoReachablePositionLeavesThePiano() {
        let range = makeController()
        for tenth in 0...Int(KeyboardRangeController.maxPosition * 10) {
            range.setPosition(Double(tenth) / 10)
            let notes = range.visibleNotes
            XCTAssertGreaterThanOrEqual(notes.low.midi, PianoNote.lowest.midi)
            XCTAssertLessThanOrEqual(notes.high.midi, PianoNote.highest.midi)
        }
    }
}
