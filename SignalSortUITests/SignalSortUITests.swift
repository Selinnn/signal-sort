import XCTest

final class SignalSortUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = [], reset: Bool = true) {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFastPlayback", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        if reset { app.launchArguments.append("-resetProgress") }
        app.launch()
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var failureBanner: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "board.failure").firstMatch
    }

    private func solveFirstLevel() {
        app.buttons["home.continue"].tap()
        XCTAssertTrue(app.buttons["board.run"].waitForExistence(timeout: 5))
        app.buttons["cell.2.2"].tap()
        XCTAssertEqual(app.staticTexts["board.moves"].label, "Moves 1 · Par 1")
        app.buttons["board.run"].tap()
        XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testFreshPlayerSolvesFirstLevelAndContinues() throws {
        launch()
        XCTAssertEqual(app.buttons["home.continue"].label, "Play")
        attachScreenshot("home-fresh")
        solveFirstLevel()
        XCTAssertTrue(app.staticTexts["result.newBest"].exists)
        XCTAssertFalse(app.buttons["result.retry"].exists)
        attachScreenshot("level1-solved")
        app.buttons["result.next"].tap()
        XCTAssertTrue(app.navigationBars["Level 2"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.continue"].label, "Continue · Level 2")
    }

    @MainActor
    func testProgressSurvivesRelaunch() throws {
        launch()
        solveFirstLevel()
        app.terminate()
        launch(reset: false)
        XCTAssertEqual(app.buttons["home.continue"].label, "Continue · Level 2")
        XCTAssertEqual(app.staticTexts["home.stars"].label, "3 of 450 stars")
    }

    @MainActor
    func testFailedRunExplainsWhyAndUndoWorks() throws {
        launch()
        app.buttons["home.continue"].tap()
        app.buttons["board.run"].tap()
        XCTAssertTrue(failureBanner.waitForExistence(timeout: 10))
        XCTAssertEqual(failureBanner.label, "The orange signal left the board.")
        attachScreenshot("level1-failure")
        app.buttons["cell.2.2"].tap()
        XCTAssertFalse(failureBanner.exists)
        XCTAssertEqual(app.staticTexts["board.moves"].label, "Moves 1 · Par 1")
        app.buttons["board.undo"].tap()
        XCTAssertEqual(app.staticTexts["board.moves"].label, "Moves 0 · Par 1")
        XCTAssertFalse(app.buttons["board.reset"].isEnabled)
    }

    @MainActor
    func testChapterMapShowsLocks() throws {
        launch()
        app.buttons["home.chapters"].tap()
        XCTAssertTrue(app.buttons["chapter.0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chapter.0"].isEnabled)
        XCTAssertFalse(app.buttons["chapter.1"].isEnabled)
        XCTAssertTrue(app.staticTexts["Finish chapter 1 to unlock"].exists)
        XCTAssertTrue(app.staticTexts["Included in the Full Game"].exists)
        attachScreenshot("chapters-fresh")
        app.buttons["chapter.0"].tap()
        XCTAssertTrue(app.buttons["level.c1-01"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["level.c1-01"].isEnabled)
        XCTAssertFalse(app.buttons["level.c1-02"].isEnabled)
        attachScreenshot("chapter1-fresh")
    }

    @MainActor
    func testHintsLeadToASolutionWithTwoStars() throws {
        launch(["-unlockAll"])
        app.buttons["home.chapters"].tap()
        app.buttons["chapter.2"].tap()
        app.buttons["level.c3-01"].tap()
        XCTAssertTrue(app.buttons["board.run"].waitForExistence(timeout: 5))
        attachScreenshot("level46-board")
        for _ in 0..<12 {
            if app.staticTexts["result.title"].exists { break }
            app.buttons["board.hint"].tap()
            app.buttons["board.run"].tap()
            _ = app.staticTexts["result.title"].waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.staticTexts["result.title"].exists)
        XCTAssertTrue(app.buttons["result.retry"].exists)
        attachScreenshot("level46-solved-with-hints")
        app.buttons["result.retry"].tap()
        XCTAssertEqual(app.staticTexts["board.moves"].label, "Moves 0 · Par 5")
    }

    @MainActor
    func testDailyPuzzleSolveShareAndStreak() throws {
        launch(["-dailyDate", "2026-11-02"])
        XCTAssertTrue(app.buttons["home.daily"].exists)
        app.buttons["home.daily"].tap()
        XCTAssertTrue(app.staticTexts["daily.streak"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["daily.streak"].label, "0-day streak")
        app.buttons["daily.2026-11-02"].tap()
        XCTAssertTrue(app.buttons["board.run"].waitForExistence(timeout: 5))
        for _ in 0..<12 {
            if app.staticTexts["result.title"].exists { break }
            app.buttons["board.hint"].tap()
            app.buttons["board.run"].tap()
            _ = app.staticTexts["result.title"].waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.buttons["result.share"].waitForExistence(timeout: 5))
        attachScreenshot("daily-solved")
        app.buttons["result.next"].tap()
        XCTAssertTrue(app.staticTexts["daily.streak"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["daily.streak"].label, "1-day streak")
        attachScreenshot("daily-list")
    }
}
