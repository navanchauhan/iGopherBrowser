# Testing

iGopherBrowser has three useful verification layers:

1. Unit tests for parsing, browser session behavior, file loading, and model helpers.
2. Fixture-backed UI tests that run against a local in-process Gopher server.
3. Opt-in live UI tests for public Gopher endpoints.

## Unit Tests

```sh
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -derivedDataPath /tmp/iGopherBrowser-unit-ios \
  COMPILER_INDEX_STORE_ENABLE=NO
```

## Fixture UI Tests

These tests avoid public network dependencies. The UI test process starts a local Gopher fixture server, launches the app with `-uiTesting`, browses fixture menus, performs a search, opens a text file, and verifies rendered content.

```sh
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -derivedDataPath /tmp/iGopherBrowser-ui-ios \
  -only-testing:iGopherBrowserUITests/BrowserEndToEndTests \
  COMPILER_INDEX_STORE_ENABLE=NO
```

## Live UI Tests

The legacy live-network UI test is disabled by default. Run it only when you explicitly want to verify a public Gopher endpoint:

```sh
RUN_LIVE_GOPHER_UI_TESTS=1 xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -derivedDataPath /tmp/iGopherBrowser-ui-live \
  -only-testing:iGopherBrowserUITests/iGopherBrowserUITests/testExample \
  COMPILER_INDEX_STORE_ENABLE=NO
```

If Xcode logs `The device is passcode protected` while these commands target a simulator, that is Xcode polling a locked physical device. It is noisy but not a test failure unless the command exits nonzero.
