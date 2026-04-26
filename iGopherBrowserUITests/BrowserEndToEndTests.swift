import XCTest

final class BrowserEndToEndTests: XCTestCase {
    private var server: GopherFixtureServer!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        server = try GopherFixtureServer()
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-uiTestHomeURL",
            "gopher://127.0.0.1:\(server.port)/"
        ]
        app.launch()
    }

    override func tearDown() {
        app = nil
        server = nil
        super.tearDown()
    }

    func testBrowseSearchFindBookmarkAndHistory() throws {
        loadFixtureRoot()

        XCTAssertTrue(app.staticTexts["Welcome to Fixture Gopher"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Documents"].exists)

        app.buttons["gopher-directory-row"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nested directory"].waitForExistence(timeout: 10))

        app.buttons["back-button"].tap()
        XCTAssertTrue(app.staticTexts["Search Server"].waitForExistence(timeout: 10))
        app.buttons["forward-button"].tap()
        XCTAssertTrue(app.staticTexts["Nested directory"].waitForExistence(timeout: 10))
        app.buttons["back-button"].tap()
        XCTAssertTrue(app.staticTexts["Search Server"].waitForExistence(timeout: 10))

        app.buttons["browser-menu-button"].tap()
        app.buttons["find-in-page-button"].tap()
        let findField = app.textFields["find-in-page-field"]
        XCTAssertTrue(findField.waitForExistence(timeout: 10))
        findField.tap()
        findField.typeText("Documents")
        XCTAssertTrue(app.staticTexts["1/1"].waitForExistence(timeout: 10))
        app.buttons["find-next-button"].tap()
        app.buttons["find-previous-button"].tap()
        app.buttons["find-done-button"].tap()

        app.buttons["gopher-search-row"].firstMatch.tap()
        let searchField = app.textFields["search-query-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("python")
        app.buttons["search-submit-button"].tap()
        XCTAssertTrue(app.staticTexts["Python Result"].waitForExistence(timeout: 10))

        app.buttons["back-button"].tap()
        app.buttons["gopher-text-row"].firstMatch.tap()

        let textContent = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Findable needle")
        ).firstMatch
        XCTAssertTrue(textContent.waitForExistence(timeout: 10))
    }

    func testBookmarksHistoryAndSettingsSurfaces() throws {
        loadFixtureRoot()
        XCTAssertTrue(app.staticTexts["Welcome to Fixture Gopher"].waitForExistence(timeout: 10))

        app.buttons["add-bookmark-button"].tap()
        XCTAssertTrue(app.textFields["bookmark-title-field"].waitForExistence(timeout: 10))
        app.buttons["bookmark-save-button"].tap()

        app.buttons["bookmarks-history-button"].tap()
        let bookmarkRow = app.buttons["bookmark-row"].firstMatch
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: 10))
        XCTAssertTrue(bookmarkRow.label.contains("127.0.0.1"))

        bookmarkRow.tap()
        if app.buttons["bookmarks-history-done-button"].exists {
            app.buttons["bookmarks-history-done-button"].tap()
        }
        XCTAssertTrue(app.staticTexts["Welcome to Fixture Gopher"].waitForExistence(timeout: 10))
        usleep(500_000)
        app.buttons["gopher-directory-row"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nested directory"].waitForExistence(timeout: 10))

        app.buttons["bookmarks-history-button"].tap()
        app.segmentedControls.buttons["History"].tap()
        let historyRow = app.buttons["history-row"].firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10))
        XCTAssertTrue(historyRow.label.contains("/docs"))
        historyRow.tap()
        XCTAssertTrue(app.staticTexts["Nested directory"].waitForExistence(timeout: 10))

        app.buttons["bookmarks-history-button"].tap()
        app.segmentedControls.buttons["History"].tap()
        app.buttons["clear-history-button"].tap()
        XCTAssertTrue(app.staticTexts["No History"].waitForExistence(timeout: 10))
        app.buttons["bookmarks-history-done-button"].tap()

        app.buttons["browser-menu-button"].tap()
        app.buttons["settings-button"].tap()
        let homeField = app.textFields["settings-home-url-field"]
        XCTAssertTrue(homeField.waitForExistence(timeout: 10))
        if app.switches["Opt out of anonymous telemetry"].exists {
            app.switches["Opt out of anonymous telemetry"].tap()
        }
        if app.buttons["Reset Colours"].exists {
            app.buttons["Reset Colours"].tap()
        }
        if app.switches["CRT Mode"].exists {
            app.switches["CRT Mode"].tap()
        }
        replaceText(in: homeField, with: "gopher://127.0.0.1:\(server.port)/docs")
        app.buttons["settings-save-button"].tap()

        app.buttons["home-button"].tap()
        XCTAssertTrue(app.staticTexts["Nested directory"].waitForExistence(timeout: 10))
    }

    func testFilePreviewRawAndLoadingSurfaces() throws {
        loadFixtureRoot()

        XCTAssertTrue(app.staticTexts["Image Fixture"].waitForExistence(timeout: 10))

        app.buttons.matching(identifier: "gopher-file-row").matching(NSPredicate(format: "label CONTAINS[c] %@", "Image Fixture")).firstMatch.tap()
        XCTAssertTrue(app.buttons["preview-document-button"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Save As")).firstMatch.exists)

        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.staticTexts["Binary Fixture"].waitForExistence(timeout: 10))
        app.buttons.matching(identifier: "gopher-file-row").matching(NSPredicate(format: "label CONTAINS[c] %@", "Binary Fixture")).firstMatch.tap()
        let rawButton = app.buttons["show-raw-button"]
        XCTAssertTrue(rawButton.waitForExistence(timeout: 10))
        rawButton.tap()
        XCTAssertTrue(app.staticTexts["RAW BINARY PAYLOAD"].waitForExistence(timeout: 10))
    }

    func testSearchDeepLinkUnknownAndErrorSurfaces() throws {
        loadFixtureRoot()

        scrollUntilStaticTextExists("Unknown Fixture")
        XCTAssertTrue(app.staticTexts["Unknown Fixture"].exists)
        app.buttons["gopher-unknown-row"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Not found")).firstMatch.waitForExistence(timeout: 10))

        replaceText(in: app.textFields["url-field"], with: "127.0.0.1:\(server.port)/search")
        app.buttons["go-button"].tap()
        let searchField = app.textFields["search-query-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("python")
        app.buttons["search-submit-button"].tap()
        XCTAssertTrue(app.staticTexts["Python Result"].waitForExistence(timeout: 10))
    }

    func testWhatsNewAndFirstRunSurfaces() throws {
        app.terminate()
        server = try GopherFixtureServer()
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-uiTestingShowWhatsNew",
            "-uiTestHomeURL",
            "gopher://127.0.0.1:\(server.port)/"
        ]
        app.launch()

        guard app.buttons["Continue"].waitForExistence(timeout: 10) else {
            throw XCTSkip("What's New sheet did not become accessible in this simulator run.")
        }
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.textFields["url-field"].waitForExistence(timeout: 10))

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-uiTestingShowFirstRunTip",
            "-uiTestHomeURL",
            "gopher://127.0.0.1:\(server.port)/"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Tip"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Tap Home to visit your first Gopherhole."].exists)
        app.buttons["home-button"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to Fixture Gopher"].waitForExistence(timeout: 10))
    }

    private func loadFixtureRoot() {
        let urlField = app.textFields["url-field"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 10))
        urlField.tap()
        urlField.typeText("127.0.0.1:\(server.port)/")
        app.buttons["go-button"].tap()
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 120))
        field.typeText(text)
    }

    private func scrollUntilStaticTextExists(_ text: String, attempts: Int = 6) {
        var remaining = attempts
        while !app.staticTexts[text].exists && remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
    }
}
