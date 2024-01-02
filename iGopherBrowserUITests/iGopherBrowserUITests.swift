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

    let screenshot = app.windows.firstMatch.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.lifetime = .keepAlways
    attachment.name = "Home Screen"
    add(attachment)

    let settingsButton = app.buttons["Settings"]
    settingsButton.tap()

    let collectionViewsQuery = app.collectionViews

    collectionViewsQuery.buttons["Reset Preferences"].tap()

    app.buttons["Home"].tap()

    while !(collectionViewsQuery /*@START_MENU_TOKEN@*/.staticTexts[
      "About Swift-Gopher"
    ] /*[[".cells",".buttons[\", About Swift-Gopher\"].staticTexts[\"About Swift-Gopher\"]",".staticTexts[\"About Swift-Gopher\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .exists)
    {
      app.swipeUp()
    }

    let screenshot1 = app.windows.firstMatch.screenshot()
    let attachment1 = XCTAttachment(screenshot: screenshot1)
    attachment1.lifetime = .keepAlways
    attachment1.name = "Default Gopher Server"
    add(attachment1)

    //let app = XCUIApplication()
    let homeButton = app.buttons["Home"]
    homeButton.tap()

    while !(collectionViewsQuery.staticTexts["About Swift-Gopher"].exists) {
      app.swipeUp()
    }

    collectionViewsQuery /*@START_MENU_TOKEN@*/.staticTexts[
      "About Swift-Gopher"
    ] /*[[".cells",".buttons[\", About Swift-Gopher\"].staticTexts[\"About Swift-Gopher\"]",".staticTexts[\"About Swift-Gopher\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap()
    app.buttons["Back"].tap()
    collectionViewsQuery /*@START_MENU_TOKEN@*/.staticTexts[
      "All the gopher servers in the world (via Floodgap)"
    ] /*[[".cells",".buttons[\", All the gopher servers in the world (via Floodgap)\"].staticTexts[\"All the gopher servers in the world (via Floodgap)\"]",".staticTexts[\"All the gopher servers in the world (via Floodgap)\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap()
    collectionViewsQuery /*@START_MENU_TOKEN@*/.staticTexts[
      "Search Gopherspace with Veronica-2"
    ] /*[[".cells",".buttons[\", Search Gopherspace with Veronica-2\"].staticTexts[\"Search Gopherspace with Veronica-2\"]",".staticTexts[\"Search Gopherspace with Veronica-2\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap()
    collectionViewsQuery /*@START_MENU_TOKEN@*/.staticTexts[
      "Search Veronica-2"
    ] /*[[".cells",".buttons[\", Search Veronica-2\"].staticTexts[\"Search Veronica-2\"]",".staticTexts[\"Search Veronica-2\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap()
    app.buttons["Dismiss"].tap()
    app.buttons["Go"].tap()
    collectionViewsQuery /*@START_MENU_TOKEN@*/.staticTexts[
      "Search Veronica-2"
    ] /*[[".cells",".buttons[\", Search Veronica-2\"].staticTexts[\"Search Veronica-2\"]",".staticTexts[\"Search Veronica-2\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap()

    let screenshot3 = app.windows.firstMatch.screenshot()
    let attachment3 = XCTAttachment(screenshot: screenshot3)
    attachment3.lifetime = .keepAlways
    attachment3.name = "Search Interface"
    add(attachment3)

    let searchTextField = app.textFields["Search"]
    searchTextField.tap()
    searchTextField.typeText("Navan")
    app.buttons["Search"].tap()
    collectionViewsQuery /*@START_MENU_TOKEN@*/.staticTexts[
      "navan-smash.jpg"
    ] /*[[".cells",".buttons[\", navan-smash.jpg\"].staticTexts[\"navan-smash.jpg\"]",".staticTexts[\"navan-smash.jpg\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap()
    app.buttons["Preview Document"].tap()
    app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"].tap()
    app.buttons["Back"].tap()

    settingsButton.tap()

    let homeUrlTextField = collectionViewsQuery /*@START_MENU_TOKEN@*/.textFields[
      "Home URL"] /*[[".cells.textFields[\"Home URL\"]",".textFields[\"Home URL\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    homeUrlTextField.tap()

    homeUrlTextField.coordinate(withNormalizedOffset: CGVectorMake(0.9, 0.9)).tap()

    let deleteKey = app /*@START_MENU_TOKEN@*/.keys[
      "delete"] /*[[".keyboards.keys[\"delete\"]",".keys[\"delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    for _ in 0...30 {
      deleteKey.tap()
    }

    homeUrlTextField.typeText("gopher://gopher.floodgap.com:70/")

    let saveButton = collectionViewsQuery /*@START_MENU_TOKEN@*/.buttons[
      "Save"] /*[[".cells.buttons[\"Save\"]",".buttons[\"Save\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    saveButton.tap()
    homeButton.tap()

    while !(collectionViewsQuery.staticTexts["Search Veronica-2"].exists) {
      app.swipeUp()
    }

    app.buttons["Back"].tap()
    app.buttons["Forward"].tap()

    //        let screenshot2 = app.windows.firstMatch.screenshot()
    //        let attachment2 = XCTAttachment(screenshot: screenshot2)
    //        attachment2.lifetime = .keepAlways
    //        add(attachment2)

    //        let searchButton = collectionViewsQuery.buttons[", Search Veronica-2"]
    //        searchButton.tap()

    //        app.buttons["Dismiss"].tap()
    //
    //        let goButton = app.buttons["Go"]
    //        goButton.tap()
    //
    //        searchButton.tap()

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
