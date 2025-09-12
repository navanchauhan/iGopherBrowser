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
