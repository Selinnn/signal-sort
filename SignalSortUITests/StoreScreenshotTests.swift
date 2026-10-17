import XCTest

/// App Store ekran görüntüleri (adım 13). `scripts/make-screenshots.sh` her dil için çalıştırır;
/// dil `SCREENSHOT_LANG` ortam değişkeniyle (en, tr, es) gelir. Normal test koşusunda dil İngilizcedir.
final class StoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String], fastPlayback: Bool = true) {
        let lang = ProcessInfo.processInfo.environment["SCREENSHOT_LANG"] ?? "en"
        let locale = ["en": "en_US", "tr": "tr_TR", "es": "es_ES"][lang] ?? "en_US"
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", locale, "-resetProgress", "-mockAds"] + extra + ["-theme", "midnight"]
        if fastPlayback { app.launchArguments.append("-uiTestFastPlayback") }
        app.launch()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func open(chapter: Int, level: String) {
        app.buttons["home.chapters"].tap()
        app.buttons["chapter.\(chapter)"].tap()
        app.buttons["level.\(level)"].tap()
        XCTAssertTrue(app.buttons["board.run"].waitForExistence(timeout: 5))
    }

    private func applyHintsUntilSolved(maxTaps: Int = 24) {
        for _ in 0..<maxTaps { app.buttons["board.hint"].tap() }
    }

    @MainActor
    func test01HeroMidRun() throws {
        launch(["-unlockAll", "-hints", "99"], fastPlayback: false)
        open(chapter: 5, level: "c6-03")
        applyHintsUntilSolved()
        app.buttons["board.run"].tap()
        Thread.sleep(forTimeInterval: 1.6)
        shot("01-hero")
    }

    @MainActor
    func test02FailureExplained() throws {
        launch(["-unlockAll"])
        open(chapter: 3, level: "c4-08")
        app.buttons["board.run"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "board.failure").firstMatch.waitForExistence(timeout: 15))
        shot("02-failure")
    }

    @MainActor
    func test03DailySolved() throws {
        launch(["-dailyDate", "2026-11-07", "-hints", "99"])
        app.buttons["home.daily"].tap()
        app.buttons["daily.2026-11-07"].tap()
        XCTAssertTrue(app.buttons["board.run"].waitForExistence(timeout: 5))
        for _ in 0..<15 {
            if app.buttons["result.share"].exists { break }
            app.buttons["board.hint"].tap()
            app.buttons["board.run"].tap()
            _ = app.buttons["result.share"].waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.buttons["result.share"].exists)
        shot("03-daily")
    }

    @MainActor
    func test04Chapters() throws {
        launch(["-seedCompleted", "58"])
        app.buttons["home.chapters"].tap()
        XCTAssertTrue(app.buttons["chapter.0"].waitForExistence(timeout: 5))
        shot("04-chapters")
    }

    @MainActor
    func test05ThemedBoard() throws {
        launch(["-unlockAll", "-theme", "ocean"])
        open(chapter: 5, level: "c6-09")
        shot("05-themes")
    }
}
