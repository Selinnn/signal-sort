import XCTest

final class SignalSortUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiTestFastPlayback", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    private func openLevel(_ index: Int) {
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
        app.buttons["level.\(index)"].tap()
        XCTAssertTrue(app.buttons["board.run"].waitForExistence(timeout: 5))
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchShowsHome() throws {
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
    }

    /// Uçtan uca: seviye 1'i aç, oku 3 kez döndür, çalıştır, sonuç ekranından sonraki seviyeye geç.
    @MainActor
    func testSolveFirstLevelAndContinue() throws {
        openLevel(0)
        attachScreenshot("level1-start")
        let router = app.buttons["cell.1.2"]
        for _ in 0..<3 { router.tap() }
        XCTAssertEqual(app.staticTexts["board.moves"].label, "Moves 3 · Par 3")
        app.buttons["board.run"].tap()
        XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 10))
        attachScreenshot("level1-solved")
        app.buttons["result.next"].tap()
        XCTAssertTrue(app.navigationBars["Level 2"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFailedRunExplainsWhyAndUndoWorks() throws {
        openLevel(0)
        app.buttons["board.run"].tap()
        let failure = app.descendants(matching: .any).matching(identifier: "board.failure").firstMatch
        XCTAssertTrue(failure.waitForExistence(timeout: 10))
        XCTAssertEqual(failure.label, "The orange signal left the board.")
        attachScreenshot("level1-failure")

        app.buttons["cell.1.2"].tap()
        XCTAssertFalse(failure.exists)
        XCTAssertEqual(app.staticTexts["board.moves"].label, "Moves 1 · Par 3")
        app.buttons["board.undo"].tap()
        XCTAssertEqual(app.staticTexts["board.moves"].label, "Moves 0 · Par 3")
        XCTAssertFalse(app.buttons["board.reset"].isEnabled)
    }

    @MainActor
    func testHintsLeadToASolution() throws {
        openLevel(3)
        for _ in 0..<12 {
            if app.staticTexts["result.title"].exists { break }
            app.buttons["board.hint"].tap()
            app.buttons["board.run"].tap()
            _ = app.staticTexts["result.title"].waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.staticTexts["result.title"].exists)
        attachScreenshot("level4-solved-with-hints")
    }

    /// Görsel kontrol için her seviyenin başlangıcı ve başarısız bir Run sonrası.
    @MainActor
    func testCaptureEveryLevel() throws {
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
        var index = 0
        while app.buttons["level.\(index)"].exists {
            openLevel(index)
            attachScreenshot("level\(index + 1)-board")
            app.buttons["board.run"].tap()
            _ = app.descendants(matching: .any).matching(identifier: "board.failure").firstMatch.waitForExistence(timeout: 10)
            attachScreenshot("level\(index + 1)-run")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            index += 1
        }
        XCTAssertGreaterThan(index, 0)
    }
}
