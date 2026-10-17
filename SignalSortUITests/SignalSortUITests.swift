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
        launch(["-unlockAll", "-hints", "99"])
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
        launch(["-dailyDate", "2026-11-02", "-hints", "99"])
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
        // İlk kez çözülen günlük +1 ipucu verir: 99 − kullanılanlar + 1.
        attachScreenshot("daily-list")
    }

    @MainActor
    func testStoreOpensWhenHintsRunOutAndFromLockedChapters() throws {
        launch(["-hints", "0"])
        app.buttons["home.continue"].tap()
        XCTAssertTrue(app.buttons["board.hint"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["board.hint.badge"].label, "+")
        app.buttons["board.hint"].tap()
        XCTAssertTrue(app.buttons["hintOffer.store"].waitForExistence(timeout: 5))
        app.buttons["hintOffer.store"].tap()
        XCTAssertTrue(app.buttons["store.restore"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["store.hintBalance"].label, "You have 0 hints")
        attachScreenshot("store")
        app.buttons["store.close"].tap()
        XCTAssertTrue(app.buttons["board.run"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["home.chapters"].tap()
        app.buttons["chapter.3"].tap()
        XCTAssertTrue(app.buttons["store.restore"].waitForExistence(timeout: 5))
        app.buttons["store.close"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["home.store"].tap()
        XCTAssertTrue(app.buttons["store.restore"].waitForExistence(timeout: 5))
    }

    private func solveWithHints() {
        for _ in 0..<15 {
            if app.staticTexts["result.title"].exists { break }
            app.buttons["board.hint"].tap()
            app.buttons["board.run"].tap()
            _ = app.staticTexts["result.title"].waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.staticTexts["result.title"].exists)
    }

    /// Ödül yalnız reklamın ödül geri çağrısında verilir: kapatmak ödül vermez.
    @MainActor
    func testRewardedAdGrantsAHintOnlyWhenEarned() throws {
        launch(["-mockAds", "-hints", "0"])
        app.buttons["home.continue"].tap()
        app.buttons["board.hint"].tap()
        app.buttons["hintOffer.watchAd"].tap()
        XCTAssertTrue(app.staticTexts["mockAd.rewarded"].waitForExistence(timeout: 5))
        app.buttons["mockAd.close"].tap()
        XCTAssertEqual(app.staticTexts["board.hint.badge"].label, "+")
        XCTAssertEqual(app.staticTexts["board.moves"].label, "Moves 0 · Par 1")

        app.buttons["board.hint"].tap()
        app.buttons["hintOffer.watchAd"].tap()
        XCTAssertTrue(app.staticTexts["mockAd.rewarded"].waitForExistence(timeout: 5))
        app.buttons["mockAd.claim"].tap()
        // Kazanılan ipucu hemen kullanılır: ok döner, bakiye yine 0.
        XCTAssertTrue(app.staticTexts["board.moves"].waitForExistence(timeout: 5))
        let moved = NSPredicate(format: "label == %@", "Moves 1 · Par 1")
        expectation(for: moved, evaluatedWith: app.staticTexts["board.moves"])
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.staticTexts["board.hint.badge"].label, "+")
    }

    @MainActor
    func testInterstitialShowsAfterTheTenthLevelThenContinues() throws {
        launch(["-mockAds", "-seedCompleted", "10", "-adsReadyForInterstitial", "-hints", "99"])
        app.buttons["home.continue"].tap()
        XCTAssertTrue(app.navigationBars["Level 11"].waitForExistence(timeout: 5))
        solveWithHints()
        app.buttons["result.next"].tap()
        XCTAssertTrue(app.staticTexts["mockAd.interstitial"].waitForExistence(timeout: 5))
        attachScreenshot("mock-interstitial")
        app.buttons["mockAd.close"].tap()
        XCTAssertTrue(app.navigationBars["Level 12"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNoInterstitialEarlyInTheGame() throws {
        launch(["-mockAds"])
        solveFirstLevel()
        app.buttons["result.next"].tap()
        XCTAssertTrue(app.navigationBars["Level 2"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["mockAd.interstitial"].exists)
    }
}
