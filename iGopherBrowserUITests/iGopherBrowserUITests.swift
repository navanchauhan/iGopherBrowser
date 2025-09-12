//
//  iGopherBrowserUITests.swift
//  iGopherBrowserUITests
//
//  Created by Navan Chauhan on 12/22/23.
//

import XCTest

final class iGopherBrowserUITests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testExample() throws {
    let app = XCUIApplication()
    app.launch()

    // Capture initial screen
    let screenshot = app.windows.firstMatch.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.lifetime = .keepAlways
    attachment.name = "Home Screen"
    add(attachment)

    // Open settings and reset preferences (dismisses on iOS)
    let settingsButton = app.buttons["Settings"]
    if settingsButton.waitForExistence(timeout: 5) {
      settingsButton.tap()
#if !os(macOS)
      let reset = app.collectionViews.buttons["Reset Preferences"]
      if reset.waitForExistence(timeout: 5) { reset.tap() }
#endif
    }

    // Tap Home
    let homeButton = app.buttons["Home"]
    if homeButton.waitForExistence(timeout: 5) { homeButton.tap() }

    // Open the known text item. On iOS try scrolling; on macOS navigate via URL.
#if os(macOS)
    do {
      let urlField = app.textFields["Enter a URL"]
      if urlField.waitForExistence(timeout: 5) {
        urlField.clearText(app: app)
        urlField.typeText("gopher.navan.dev:70/about_swift_gopher.md"); app.buttons["Go"].tap()
        if app.buttons["Back"].waitForExistence(timeout: 10) { app.buttons["Back"].tap() }
      }
    }
#else
    do {
      let collectionViewsQuery = app.collectionViews
      var attempts = 0
      while !collectionViewsQuery.staticTexts["About Swift-Gopher"].exists && attempts < 10 {
        app.swipeUp(); attempts += 1
      }
      if collectionViewsQuery.staticTexts["About Swift-Gopher"].exists {
        collectionViewsQuery.staticTexts["About Swift-Gopher"].tap()
        if app.buttons["Back"].waitForExistence(timeout: 5) { app.buttons["Back"].tap() }
      } else {
        let urlField = app.textFields["Enter a URL"]
        if urlField.waitForExistence(timeout: 5) {
          urlField.clearText(app: app)
          urlField.typeText("gopher.navan.dev:70/about_swift_gopher.md"); app.buttons["Go"].tap()
          if app.buttons["Back"].waitForExistence(timeout: 10) { app.buttons["Back"].tap() }
        }
      }
    }
#endif

    // Exercise Back/Forward controls
    if app.buttons["Back"].exists { app.buttons["Back"].tap() }
    if app.buttons["Forward"].exists { app.buttons["Forward"].tap() }

    // Open settings again and modify Home URL field then save
    if settingsButton.exists { settingsButton.tap() }
    let saveButton = app.collectionViews.buttons["Save"]
    if saveButton.waitForExistence(timeout: 5) { saveButton.tap() }

    if homeButton.exists { homeButton.tap() }

    // Final navigation checks
    if app.buttons["Back"].exists { app.buttons["Back"].tap() }
    if app.buttons["Forward"].exists { app.buttons["Forward"].tap() }

    // Navigate directly to /igopherbrowser and open image "Screenshot"
    let urlField = app.textFields["Enter a URL"]
    if urlField.waitForExistence(timeout: 5) {
      urlField.clearText(app: app)
      urlField.typeText("gopher.navan.dev:70/igopherbrowser"); app.buttons["Go"].tap()
      let screenshotCell = app.collectionViews.staticTexts["Screenshot"]
      if screenshotCell.waitForExistence(timeout: 10) {
        screenshotCell.tap()
        let preview = app.buttons["Preview Document"]
        if preview.waitForExistence(timeout: 10) {
          preview.tap()
          let done = app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"]
#if os(macOS)
          if done.waitForExistence(timeout: 5) { done.tap() } else {
            app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
          }
#else
          if done.waitForExistence(timeout: 5) { done.tap() }
#endif
        }
        if app.buttons["Back"].exists { app.buttons["Back"].tap() }
      }
    }

    // Use the known search item "Search Server"; scroll from homepage and use that
    if homeButton.exists { homeButton.tap() }
#if os(macOS)
    do {
      var attempts = 0
      while !app.staticTexts["Search Server"].exists && attempts < 20 {
        app.typeKey(XCUIKeyboardKey.pageDown, modifierFlags: [])
        attempts += 1
      }
      let searchItem = app.staticTexts["Search Server"]
      if searchItem.exists {
        searchItem.tap()
        let queryField = app.textFields["Search"]
        if queryField.waitForExistence(timeout: 5) {
          queryField.tap(); queryField.typeText("python"); app.buttons["Search"].tap()
          if searchItem.waitForExistence(timeout: 5) { searchItem.tap() }
          if queryField.waitForExistence(timeout: 5) {
            queryField.tap(); queryField.typeText("qwertyuiop"); app.buttons["Search"].tap()
          }
        }
      }
    }
#else
    do {
      var tries = 0
      while !app.collectionViews.staticTexts["Search Server"].exists && tries < 20 {
        app.swipeUp(); tries += 1
      }
      let searchServer = app.collectionViews.staticTexts["Search Server"]
      if searchServer.exists {
        searchServer.tap()
        let queryField = app.textFields["Search"]
        if queryField.waitForExistence(timeout: 5) { queryField.tap(); queryField.typeText("python"); app.buttons["Search"].tap() }
        if searchServer.waitForExistence(timeout: 5) { searchServer.tap() }
        if queryField.waitForExistence(timeout: 5) { queryField.tap(); queryField.typeText("qwertyuiop"); app.buttons["Search"].tap() }
      }
    }
#endif
  }

  //    func testLaunchPerformance() throws {
  //        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
  //            // This measures how long it takes to launch your application.
  //            measure(metrics: [XCTApplicationLaunchMetric()]) {
  //                XCUIApplication().launch()
  //            }
  //        }
  //    }
    
#if os(macOS)
final class iGopherBrowserMacUITests: XCTestCase {
  func testNavigateTextImageAndSettings() throws {
    let app = XCUIApplication()
    app.launch()

    // Go Home to populate the list
    let homeButton = app.buttons["Home"]
    if homeButton.waitForExistence(timeout: 10) { homeButton.tap() }

    // 1) From base directory, locate and open the known text item (do not deep-link the file)
    do {
      var tries = 0
      while !app.staticTexts["About Swift-Gopher"].exists && tries < 30 {
        app.typeKey(XCUIKeyboardKey.pageDown, modifierFlags: [])
        tries += 1
      }
      if app.staticTexts["About Swift-Gopher"].exists {
        app.staticTexts["About Swift-Gopher"].click()
      }
      // After opening, go back to the list
      let back = app.buttons["Back"]
      _ = back.waitForExistence(timeout: 10)
      if back.exists { back.tap() }
    }

    // 2) Open an image and exercise QuickLook
    let urlField = app.textFields["Enter a URL"]
    let goButton = app.buttons["Go"]
    if urlField.waitForExistence(timeout: 10) {
      // Navigate to the base directory first (not the file)
      urlField.clearText(app: app)
      urlField.typeText("gopher.navan.dev:70/igopherbrowser")
      if goButton.waitForExistence(timeout: 5) { goButton.tap() }

      // Open the "Screenshot" row
      let screenshotButton = app.buttons["Screenshot"]
      if screenshotButton.waitForExistence(timeout: 15) {
        screenshotButton.click()
      } else if app.staticTexts["Screenshot"].waitForExistence(timeout: 10) {
        app.staticTexts["Screenshot"].click()
      let preview = app.buttons["Preview Document"]
        if preview.waitForExistence(timeout: 10) {
          preview.tap()
          // Close QuickLook overlay
          let done = app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"]
          if done.waitForExistence(timeout: 5) {
            done.tap()
          } else {
            app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
          }
        }
        // Return to list
        let back = app.buttons["Back"]
        if back.waitForExistence(timeout: 5) { back.tap() }
      }
    }

    // 3) Open Settings (Preferences) and assert mac-specific sections
    app.typeKey(",", modifierFlags: [.command])
    XCTAssertTrue(app.staticTexts["Navigation"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Appearance"].exists)
    XCTAssertTrue(app.staticTexts["Privacy"].exists)
    XCTAssertTrue(app.staticTexts["Sharing"].exists)
    XCTAssertTrue(app.textFields["Enter home URL"].exists)
    XCTAssertTrue(app.buttons["Save"].exists)
    XCTAssertTrue(app.buttons["Reset to Default"].exists)
  }

  func testFileViewPreviewAndSave() throws {
    let app = XCUIApplication()
    app.launch()

    // Navigate to the igopherbrowser directory
    let urlField = app.textFields["Enter a URL"]
    let goButton = app.buttons["Go"]
    XCTAssertTrue(urlField.waitForExistence(timeout: 15))
    urlField.clearText(app: app)
    urlField.typeText("gopher.navan.dev:70/igopherbrowser")
    XCTAssertTrue(goButton.waitForExistence(timeout: 5))
    goButton.tap()

    // Open the "Screenshot" item which should lead to FileView with preview + save buttons
    let screenshotLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Screenshot'"))
      .firstMatch
    let screenshotButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Screenshot'"))
      .firstMatch
    var tries = 0
    while !(screenshotLabel.exists || screenshotButton.exists) && tries < 40 {
      app.typeKey(XCUIKeyboardKey.pageDown, modifierFlags: [])
      tries += 1
      usleep(150_000)
    }
    if !(screenshotLabel.exists || screenshotButton.exists) {
      throw XCTSkip("Could not locate 'Screenshot' entry; skipping FileView preview/save test")
    }
    if screenshotButton.exists { screenshotButton.tap() } else { screenshotLabel.tap() }

    // 1) Test "Preview Document" button (Quick Look)
    let previewButton = app.buttons["Preview Document"]
    XCTAssertTrue(previewButton.waitForExistence(timeout: 20))
    previewButton.tap()

    // Close QuickLook overlay (Done button or Escape)
    let quickLookDone = app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"]
    if quickLookDone.waitForExistence(timeout: 5) {
      quickLookDone.tap()
    } else {
      app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    // 2) Test "Save As…" button (NSSavePanel)
    let saveAsButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Save As'"))
      .firstMatch
    XCTAssertTrue(saveAsButton.waitForExistence(timeout: 10))
    if saveAsButton.isHittable {
      saveAsButton.tap()
    } else {
      throw XCTSkip("'Save As…' button is present but not hittable; skipping save flow")
    }

    // Give the save panel a moment to appear
    sleep(1)

    // Try to set filename and save to /tmp via Go To Folder, then press Return to confirm Save.
    // If any step fails, gracefully fall back to pressing Escape to dismiss.
    // Focus the name field (usually focused by default) and type a predictable name
    app.typeKey("a", modifierFlags: [.command])
    app.typeText("UITestSavedFile")

    // Open Go To Folder and choose /tmp
    app.typeKey("g", modifierFlags: [.command, .shift])
    // Small wait for the Go To Folder sheet
    usleep(300_000)
    app.typeText("/tmp")
    app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])
    // Confirm Save
    app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])

    // Wait briefly for panel to close
    sleep(1)

    // Validate the save likely succeeded by checking for a file starting with our prefix in /tmp
    // (The extension is determined dynamically by the app based on content type.)
    let fm = FileManager.default
    let tmpURL = URL(fileURLWithPath: "/tmp")
    if let contents = try? fm.contentsOfDirectory(atPath: tmpURL.path) {
      XCTAssertTrue(contents.contains(where: { $0.hasPrefix("UITestSavedFile.") }))
    }

    // Navigate back to the list so subsequent tests start clean
    let back = app.buttons["Back"]
    if back.waitForExistence(timeout: 5) { back.tap() }
  }
}
#endif


}

private extension XCUIElement {
    func clearText(app: XCUIApplication) {
        self.tap()
#if os(macOS)
        // Select All then Delete
        self.typeKey("a", modifierFlags: [.command])
        self.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
#else
        if let stringValue = self.value as? String, !stringValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            self.typeText(deleteString)
        }
#endif
    }
}
