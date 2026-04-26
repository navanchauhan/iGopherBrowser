# iGopherBrowser Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make iGopherBrowser easier to evolve by separating browser logic from SwiftUI views, fixing navigation/test harness issues, and adding deterministic unit plus end-to-end coverage for browsing, search, bookmarks/history, and file preview flows.

**Architecture:** Keep SwiftUI as the presentation layer, but move URL parsing, navigation history, request cancellation, and file loading into small testable Swift types. Use `@Observable`/`@State` for view-owned browser state, protocol-based fetchers for deterministic tests, SwiftData only at the view/app boundary, and XCTest UI tests backed by an in-process local gopher fixture server.

**Tech Stack:** SwiftUI, SwiftData, SwiftGopherClient, TelemetryDeck, Swift Testing for unit/integration tests, XCTest for UI tests, Xcode schemes/test plans, iOS 17+/macOS 14+/visionOS target support.

---

## Current Baseline

- `xcodebuild -list -project iGopherBrowser.xcodeproj` succeeds and reports schemes `iGopherBrowser`, `iGopherBrowserTests`, and `iGopherBrowserUITests`.
- iOS unit tests currently cannot start: `iGopherBrowserTests` resolves `TEST_HOST` to `.../iGopherBrowser.app/Contents/MacOS/iGopherBrowser`, which is the macOS app executable layout, not iOS simulator layout. The setting is in `iGopherBrowser.xcodeproj/project.pbxproj:648` and `iGopherBrowser.xcodeproj/project.pbxproj:675`.
- The existing unit tests are XCTest-only in `iGopherBrowserTests/iGopherBrowserTests.swift`; several are view body smoke tests rather than behavior tests.
- Existing UI tests in `iGopherBrowserUITests/iGopherBrowserUITests.swift` drive real public content at `gopher.navan.dev`, contain conditional skips, and have brittle selectors. They should become deterministic fixture-backed E2E tests.
- I interrupted one iOS simulator build after Xcode repeatedly logged a passcode-protected physical device error. Treat the app build as unverified in this pass until the device is unlocked/disconnected or Xcode device polling settles.
- Do not run multiple `xcodebuild` commands against the same DerivedData path in parallel; that caused a build database lock in this inspection.

## File Map

- Modify `iGopherBrowser.xcodeproj/project.pbxproj`: fix SDK-specific `TEST_HOST`; add new Swift files to the app/test targets as they are introduced.
- Create `iGopherBrowser/GopherLocation.swift`: canonical gopher URL parsing and formatting.
- Create `iGopherBrowser/GopherFetching.swift`: live and mockable gopher fetch abstraction.
- Create `iGopherBrowser/BrowserSession.swift`: `@Observable` navigation, loading, find, and history state.
- Modify `iGopherBrowser/BrowserView.swift`: delegate browsing behavior to `BrowserSession`, split rows, fix back/forward behavior, add accessibility identifiers.
- Create `iGopherBrowser/GopherItemRow.swift`: row rendering and actions for directory/search/file/link/info items.
- Modify `iGopherBrowser/SidebarView.swift`: replace `onTapGesture` with accessible `Button`.
- Modify `iGopherBrowser/SearchInputView.swift`: use `@Environment(\.dismiss)` and clearer accessibility identifiers.
- Modify `iGopherBrowser/SettingsView.swift`: modernize deprecated SwiftUI APIs and keep duplicated platform branches minimal.
- Create `iGopherBrowser/GopherFileLoader.swift`: async file download, type detection, temp-file writing, and text chunking.
- Modify `iGopherBrowser/FileView.swift`: use `GopherFileLoader` and `.task(id:)`, avoid callback-driven state mutation.
- Create `iGopherBrowser/LaunchConfiguration.swift`: deterministic UI-test startup settings.
- Create `iGopherBrowserTests/GopherLocationTests.swift`.
- Create `iGopherBrowserTests/BrowserSessionTests.swift`.
- Create `iGopherBrowserTests/GopherFileLoaderTests.swift`.
- Create `iGopherBrowserUITests/GopherFixtureServer.swift`.
- Create `iGopherBrowserUITests/BrowserEndToEndTests.swift`.
- Replace or retire broad `testExample()` in `iGopherBrowserUITests/iGopherBrowserUITests.swift` after fixture-backed tests cover the same behavior.

---

### Task 1: Repair The Test Harness

**Files:**
- Modify: `iGopherBrowser.xcodeproj/project.pbxproj:626-676`
- Modify later as needed: `iGopherBrowser.xcodeproj/xcshareddata/xcschemes/iGopherBrowserTests.xcscheme`

- [ ] **Step 1: Fix SDK-specific unit-test host paths**

In both Debug and Release build settings for `iGopherBrowserTests`, replace the single unconditional `TEST_HOST` with SDK-specific values:

```pbxproj
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/iGopherBrowser.app/Contents/MacOS/iGopherBrowser";
"TEST_HOST[sdk=iphoneos*]" = "$(BUILT_PRODUCTS_DIR)/iGopherBrowser.app/iGopherBrowser";
"TEST_HOST[sdk=iphonesimulator*]" = "$(BUILT_PRODUCTS_DIR)/iGopherBrowser.app/iGopherBrowser";
"TEST_HOST[sdk=macosx*]" = "$(BUILT_PRODUCTS_DIR)/iGopherBrowser.app/Contents/MacOS/iGopherBrowser";
```

Leave:

```pbxproj
BUNDLE_LOADER = "$(TEST_HOST)";
TEST_TARGET_NAME = iGopherBrowser;
```

- [ ] **Step 2: Verify iOS unit tests can at least launch**

Run:

```bash
DERIVED_DATA=/tmp/iGopherBrowser-unit-ios
rm -rf "$DERIVED_DATA"
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -derivedDataPath "$DERIVED_DATA" \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: the previous `Could not find test host` error is gone. Test assertions may still fail; record those separately.

- [ ] **Step 3: Verify macOS unit tests still use the macOS app executable path**

Run:

```bash
DERIVED_DATA=/tmp/iGopherBrowser-unit-macos
rm -rf "$DERIVED_DATA"
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: build/test starts without a `TEST_HOST` layout error. If a connected locked device causes repeated `DTDKRemoteDeviceConnection` logs, unlock or disconnect it before treating failures as project failures.

- [ ] **Step 4: Commit**

```bash
git add iGopherBrowser.xcodeproj/project.pbxproj
git commit -m "test: fix platform-specific unit test host"
```

---

### Task 2: Replace Ad Hoc URL Parsing With `GopherLocation`

**Files:**
- Create: `iGopherBrowser/GopherLocation.swift`
- Modify: `iGopherBrowser/Helpers.swift:11-44`
- Create: `iGopherBrowserTests/GopherLocationTests.swift`
- Modify: `iGopherBrowser.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add behavior tests first**

Create `iGopherBrowserTests/GopherLocationTests.swift`:

```swift
import Testing
@testable import iGopherBrowser

struct GopherLocationTests {
    @Test(
        "Parses common gopher location inputs",
        arguments: [
            ("gopher://example.com:70/some/path", "example.com", 70, "/some/path"),
            ("localhost:7070/some/dir", "localhost", 7070, "/some/dir"),
            ("just-a-hostname", "just-a-hostname", 70, "/"),
            ("example.org:x/path", "example.org", 72, "/path"),
            ("gopher://example.com/search%09python", "example.com", 70, "/search\tpython")
        ]
    )
    func parsesInputs(input: String, host: String, port: Int, selector: String) {
        let location = GopherLocation(input, defaultPort: 72)
        #expect(location.host == host)
        #expect(location.port == port)
        #expect(location.selector == selector)
    }

    @Test("Formats display and URL strings consistently")
    func formatsStrings() {
        let location = GopherLocation(host: "example.com", port: 70, selector: "/about")
        #expect(location.displayString == "example.com:70/about")
        #expect(location.gopherURL.absoluteString == "gopher://example.com:70/about")
    }
}
```

- [ ] **Step 2: Run the new tests and verify they fail before implementation**

Run:

```bash
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -only-testing:iGopherBrowserTests/GopherLocationTests \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: compile failure because `GopherLocation` does not exist yet.

- [ ] **Step 3: Implement `GopherLocation`**

Create `iGopherBrowser/GopherLocation.swift`:

```swift
import Foundation

struct GopherLocation: Hashable, Identifiable, Sendable {
    let host: String
    let port: Int
    let selector: String

    var id: String { displayString }
    var displayString: String { "\(host):\(port)\(selector.normalizedGopherSelector)" }
    var gopherURL: URL { URL(string: "gopher://\(displayString)")! }

    init(host: String, port: Int = 70, selector: String = "/") {
        self.host = host.isEmpty ? "gopher.navan.dev" : host
        self.port = port
        self.selector = selector.normalizedGopherSelector.removingPercentEncoding ?? selector.normalizedGopherSelector
    }

    init(_ input: String, defaultPort: Int = 70, defaultHost: String = "gopher.navan.dev") {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parseCandidate = raw.contains("://") ? raw : "gopher://\(raw)"

        if let components = URLComponents(string: parseCandidate), let host = components.host {
            self.init(
                host: host,
                port: components.port ?? defaultPort,
                selector: components.path.normalizedGopherSelector
            )
            return
        }

        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        let host = parts.first?.isEmpty == false ? parts[0] : defaultHost
        guard parts.count == 2 else {
            self.init(host: host, port: defaultPort, selector: "/")
            return
        }

        let portAndSelector = parts[1].split(separator: "/", maxSplits: 1).map(String.init)
        let port = Int(portAndSelector.first ?? "") ?? defaultPort
        let selector = portAndSelector.count == 2 ? "/\(portAndSelector[1])" : "/"
        self.init(host: host, port: port, selector: selector)
    }
}

private extension String {
    var normalizedGopherSelector: String {
        if isEmpty { return "/" }
        return hasPrefix("/") ? self : "/\(self)"
    }
}
```

- [ ] **Step 4: Make the old helper delegate to the new type**

Replace `getHostAndPort` in `iGopherBrowser/Helpers.swift` with:

```swift
import Foundation
import SwiftGopherClient

public func getHostAndPort(
    from urlString: String,
    defaultPort: Int = 70,
    defaultHost: String = "gopher.navan.dev"
) -> (host: String, port: Int, selector: String) {
    let location = GopherLocation(urlString, defaultPort: defaultPort, defaultHost: defaultHost)
    return (location.host, location.port, location.selector)
}
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -only-testing:iGopherBrowserTests/GopherLocationTests \
  -only-testing:iGopherBrowserTests/iGopherBrowserTests/testGetHostAndPort_withFullURL \
  -only-testing:iGopherBrowserTests/iGopherBrowserTests/testGetHostAndPort_simpleHostPortAndPath \
  -only-testing:iGopherBrowserTests/iGopherBrowserTests/testGetHostAndPort_defaultsApplied \
  -only-testing:iGopherBrowserTests/iGopherBrowserTests/testGetHostAndPort_portAndSelectorFallback \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: all parsing tests pass.

- [ ] **Step 6: Commit**

```bash
git add iGopherBrowser/GopherLocation.swift iGopherBrowser/Helpers.swift iGopherBrowserTests/GopherLocationTests.swift iGopherBrowser.xcodeproj/project.pbxproj
git commit -m "refactor: centralize gopher location parsing"
```

---

### Task 3: Extract Browser State And Fix Navigation

**Files:**
- Create: `iGopherBrowser/GopherFetching.swift`
- Create: `iGopherBrowser/BrowserSession.swift`
- Create: `iGopherBrowserTests/BrowserSessionTests.swift`
- Modify: `iGopherBrowser/BrowserView.swift:34-697`
- Modify: `iGopherBrowser.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write tests for navigation, search prompts, stale responses, and forward behavior**

Create `iGopherBrowserTests/BrowserSessionTests.swift`:

```swift
import GopherHelpers
import Testing
@testable import iGopherBrowser

@MainActor
struct BrowserSessionTests {
    @Test("Forward uses the forward stack, not the back stack")
    func forwardUsesForwardStack() async throws {
        let fetcher = MockGopherFetcher(itemsBySelector: [
            "/": [FixtureItems.directory("About", selector: "/about")],
            "/about": [FixtureItems.info("About page")]
        ])
        let session = BrowserSession(fetcher: fetcher)

        await session.load(GopherLocation(host: "example.com", selector: "/"))
        await session.load(GopherLocation(host: "example.com", selector: "/about"))
        await session.goBack()
        await session.goForward()

        #expect(session.currentLocation?.selector == "/about")
        #expect(session.forwardStack.isEmpty)
    }

    @Test("Search selector without query opens search prompt instead of fetching")
    func searchWithoutQueryOpensPrompt() async {
        let session = BrowserSession(fetcher: MockGopherFetcher(itemsBySelector: [:]))
        await session.load(GopherLocation(host: "example.com", selector: "/search"))
        #expect(session.searchContext == .init(host: "example.com", port: 70, selector: "/search"))
        #expect(session.items.isEmpty)
    }

    @Test("Newer navigation wins over stale responses")
    func newerNavigationWins() async throws {
        let fetcher = MockGopherFetcher(
            itemsBySelector: [
                "/slow": [FixtureItems.info("Slow")],
                "/fast": [FixtureItems.info("Fast")]
            ],
            delayedSelectors: ["/slow"]
        )
        let session = BrowserSession(fetcher: fetcher)

        let slow = Task { await session.load(GopherLocation(host: "example.com", selector: "/slow")) }
        await session.load(GopherLocation(host: "example.com", selector: "/fast"))
        await slow.value

        #expect(session.items.map(\.message) == ["Fast"])
        #expect(session.currentLocation?.selector == "/fast")
    }
}
```

Add test fixtures in the same file:

```swift
private enum FixtureItems {
    static func info(_ message: String) -> gopherItem {
        var item = gopherItem(rawLine: "i\(message)\tfake\tlocalhost\t70")
        item.message = message
        return item
    }

    static func directory(_ message: String, selector: String) -> gopherItem {
        var item = gopherItem(rawLine: "1\(message)\t\(selector)\texample.com\t70")
        item.message = message
        item.host = "example.com"
        item.port = 70
        item.selector = selector
        return item
    }
}

private struct MockGopherFetcher: GopherFetching {
    var itemsBySelector: [String: [gopherItem]]
    var delayedSelectors: Set<String> = []

    func fetch(_ location: GopherLocation) async throws -> [gopherItem] {
        if delayedSelectors.contains(location.selector) {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return itemsBySelector[location.selector] ?? []
    }
}
```

- [ ] **Step 2: Run tests and confirm failure**

Run:

```bash
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -only-testing:iGopherBrowserTests/BrowserSessionTests \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: compile failure because `GopherFetching` and `BrowserSession` do not exist yet.

- [ ] **Step 3: Add the fetch abstraction**

Create `iGopherBrowser/GopherFetching.swift`:

```swift
import SwiftGopherClient

protocol GopherFetching {
    func fetch(_ location: GopherLocation) async throws -> [gopherItem]
}

struct LiveGopherFetcher: GopherFetching {
    private let client = GopherClient()

    func fetch(_ location: GopherLocation) async throws -> [gopherItem] {
        try await client.sendRequest(
            to: location.host,
            port: location.port,
            message: "\(location.selector)\r\n"
        )
    }
}
```

- [ ] **Step 4: Add `BrowserSession`**

Create `iGopherBrowser/BrowserSession.swift`:

```swift
import GopherHelpers
import Observation
import SwiftUI

@MainActor
@Observable
final class BrowserSession {
    var urlText = ""
    var items: [gopherItem] = []
    var hosts: [GopherNode] = []
    var currentLocation: GopherLocation?
    var backwardStack: [GopherLocation] = []
    var forwardStack: [GopherLocation] = []
    var searchContext: SearchContext?
    var findText = ""
    var currentFindIndex = 0
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private let fetcher: any GopherFetching
    @ObservationIgnored private var currentTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    var findMatches: [Int] {
        guard findText.isEmpty == false else { return [] }
        return items.enumerated().compactMap { index, item in
            item.message.localizedCaseInsensitiveContains(findText) ? index : nil
        }
    }

    init(fetcher: any GopherFetching = LiveGopherFetcher()) {
        self.fetcher = fetcher
    }

    deinit {
        currentTask?.cancel()
    }

    func load(_ location: GopherLocation, clearForward: Bool = true) async {
        let normalized = normalizedSearchLocation(location)
        guard let normalized else { return }

        currentTask?.cancel()
        requestID = UUID()
        let activeRequestID = requestID

        urlText = normalized.displayString
        currentLocation = normalized
        isLoading = true
        errorMessage = nil

        currentTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await fetcher.fetch(normalized)
                try Task.checkCancellation()
                guard self.requestID == activeRequestID else { return }
                self.apply(response, for: normalized, clearForward: clearForward)
            } catch is CancellationError {
                return
            } catch {
                guard self.requestID == activeRequestID else { return }
                self.errorMessage = String(describing: error)
                var item = gopherItem(rawLine: "Error \(error)")
                item.message = "Error \(error)"
                self.items = [item]
            }
            self.isLoading = false
        }

        await currentTask?.value
    }

    func goBack() async {
        guard backwardStack.count >= 2 else { return }
        let current = backwardStack.removeLast()
        forwardStack.append(current)
        let previous = backwardStack.removeLast()
        await load(previous, clearForward: false)
    }

    func goForward() async {
        guard let next = forwardStack.popLast() else { return }
        await load(next, clearForward: false)
    }

    private func normalizedSearchLocation(_ location: GopherLocation) -> GopherLocation? {
        let selector = location.selector.removingPercentEncoding ?? location.selector
        if selector.hasPrefix("/search"), selector.contains("\t") == false {
            searchContext = SearchContext(host: location.host, port: location.port, selector: "/search")
            return nil
        }
        searchContext = nil
        return GopherLocation(host: location.host, port: location.port, selector: selector)
    }

    private func apply(_ response: [gopherItem], for location: GopherLocation, clearForward: Bool) {
        items = response
        backwardStack.append(location)
        if clearForward { forwardStack.removeAll() }
        mergeSidebarItems(response, for: location)
    }

    private func mergeSidebarItems(_ response: [gopherItem], for location: GopherLocation) {
        var node = GopherNode(
            host: location.host,
            port: location.port,
            selector: location.selector,
            item: nil,
            children: response.compactMap { item in
                guard item.parsedItemType != .info else { return nil }
                return GopherNode(
                    host: item.host,
                    port: item.port,
                    selector: item.selector,
                    message: item.message,
                    item: item,
                    children: nil
                )
            }
        )

        if let index = hosts.firstIndex(where: { $0.host == location.host && $0.port == location.port }) {
            hosts[index].children = hosts[index].children?.map { child in
                if child.selector == location.selector {
                    node.message = child.message
                    return node
                }
                return child
            }
        } else {
            node.selector = "/"
            hosts.append(node)
        }
    }
}

struct SearchContext: Equatable {
    let host: String
    let port: Int
    let selector: String
}
```

- [ ] **Step 5: Wire `BrowserView` through `BrowserSession`**

In `BrowserView`, replace duplicated state and `performGopherRequest` ownership with a single session:

```swift
@State private var session = BrowserSession()
```

Then route actions through:

```swift
Task {
    await session.load(GopherLocation(session.urlText))
}
```

For history insertion, keep SwiftData at the view boundary:

```swift
private func saveHistory(for location: GopherLocation) {
    modelContext.insert(
        HistoryItem(
            title: "\(location.host)\(location.selector)",
            host: location.host,
            port: location.port,
            selector: location.selector
        )
    )
}
```

Call `saveHistory(for:)` only after a successful non-stale load.

- [ ] **Step 6: Run tests**

Run:

```bash
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -only-testing:iGopherBrowserTests/BrowserSessionTests \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: `BrowserSessionTests` pass, especially forward navigation.

- [ ] **Step 7: Commit**

```bash
git add iGopherBrowser/GopherFetching.swift iGopherBrowser/BrowserSession.swift iGopherBrowser/BrowserView.swift iGopherBrowserTests/BrowserSessionTests.swift iGopherBrowser.xcodeproj/project.pbxproj
git commit -m "refactor: extract browser session state"
```

---

### Task 4: Make The SwiftUI Surface Smaller, Modern, And Testable

**Files:**
- Create: `iGopherBrowser/GopherItemRow.swift`
- Modify: `iGopherBrowser/BrowserView.swift`
- Modify: `iGopherBrowser/SidebarView.swift:26-35`
- Modify: `iGopherBrowser/SearchInputView.swift:18-51`
- Modify: `iGopherBrowser/SettingsView.swift:101-378`
- Modify: `iGopherBrowser.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add stable accessibility identifiers before rewriting UI tests**

Add identifiers in `BrowserView` toolbars:

```swift
TextField("Enter URL", text: $session.urlText)
    .accessibilityIdentifier("url-field")

Button(action: onGo) {
    Text("Go")
}
.accessibilityIdentifier("go-button")

Button(action: onHome) {
    Image(systemName: "house")
}
.accessibilityIdentifier("home-button")
```

Add identifiers for sheet triggers:

```swift
.accessibilityIdentifier("bookmarks-history-button")
.accessibilityIdentifier("add-bookmark-button")
.accessibilityIdentifier("settings-button")
.accessibilityIdentifier("find-in-page-button")
```

- [ ] **Step 2: Extract a row view**

Create `iGopherBrowser/GopherItemRow.swift`:

```swift
import GopherHelpers
import SwiftUI

struct GopherItemRow: View {
    let item: gopherItem
    let linkColor: Color
    let textColor: Color
    let crtMode: Bool
    let openDirectory: (gopherItem) -> Void
    let openSearch: (gopherItem) -> Void
    let openExternalURL: (URL) -> Void

    var body: some View {
        switch item.parsedItemType {
        case .info:
            Text(item.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(textColor)
                .accessibilityIdentifier("gopher-info-row")
        case .directory:
            rowButton(systemImage: "folder", title: item.message) { openDirectory(item) }
                .accessibilityIdentifier("gopher-directory-row")
        case .search:
            rowButton(systemImage: "magnifyingglass", title: item.message) { openSearch(item) }
                .accessibilityIdentifier("gopher-search-row")
        case .text:
            NavigationLink(destination: FileView(item: item)) {
                rowLabel(systemImage: "doc.plaintext", title: item.message)
            }
            .accessibilityIdentifier("gopher-text-row")
        default:
            if item.selector.hasPrefix("URL:"),
               let url = URL(string: item.selector.replacingOccurrences(of: "URL:", with: "")) {
                rowButton(systemImage: "link", title: item.message) { openExternalURL(url) }
                    .accessibilityIdentifier("gopher-external-link-row")
            } else if [.doc, .image, .gif, .movie, .sound, .bitmap, .binary].contains(item.parsedItemType) {
                NavigationLink(destination: FileView(item: item)) {
                    rowLabel(systemImage: itemToImageType(item), title: item.message)
                }
                .accessibilityIdentifier("gopher-file-row")
            } else {
                rowButton(systemImage: "questionmark.app.dashed", title: item.message) { openDirectory(item) }
                    .accessibilityIdentifier("gopher-unknown-row")
            }
        }
    }

    private func rowButton(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(systemImage: systemImage, title: title)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(systemImage: String, title: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(title)
            Spacer()
        }
        .contentShape(Rectangle())
        .foregroundStyle(linkColor)
        .shadow(color: crtMode ? linkColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 3: Replace `SidebarView` tap gesture with `Button`**

Change `SidebarView` rows to:

```swift
Button {
    onSelect(node)
} label: {
    Text(node.message ?? node.host)
        .foregroundStyle(textColor)
        .shadow(color: crtMode ? textColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
}
.buttonStyle(.plain)
```

- [ ] **Step 4: Modernize dismiss and text input APIs**

In `SearchInputView`, replace:

```swift
@Environment(\.presentationMode) var presentationMode
```

with:

```swift
@Environment(\.dismiss) private var dismiss
```

Then replace all `presentationMode.wrappedValue.dismiss()` calls with `dismiss()`.

In `SettingsView`, replace:

```swift
.disableAutocorrection(true)
.foregroundColor(.secondary)
.foregroundColor(.gray)
.alert(isPresented: $showAlert) { ... }
```

with:

```swift
.autocorrectionDisabled(true)
.foregroundStyle(.secondary)
.foregroundStyle(.secondary)
.alert("Error Saving", isPresented: $showAlert) {
    Button("Got it") {}
} message: {
    Text(alertMessage)
}
```

- [ ] **Step 5: Run SwiftUI smoke build**

Run:

```bash
xcodebuild build \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowser \
  -destination 'generic/platform=iOS Simulator' \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: build succeeds without deprecated API warnings from touched files.

- [ ] **Step 6: Commit**

```bash
git add iGopherBrowser/GopherItemRow.swift iGopherBrowser/BrowserView.swift iGopherBrowser/SidebarView.swift iGopherBrowser/SearchInputView.swift iGopherBrowser/SettingsView.swift iGopherBrowser.xcodeproj/project.pbxproj
git commit -m "refactor: simplify browser SwiftUI surface"
```

---

### Task 5: Make File Loading Async, Cancelable, And Testable

**Files:**
- Create: `iGopherBrowser/GopherFileLoader.swift`
- Modify: `iGopherBrowser/FileView.swift:46-198`
- Create: `iGopherBrowserTests/GopherFileLoaderTests.swift`
- Modify: `iGopherBrowser.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write file-loader tests**

Create `iGopherBrowserTests/GopherFileLoaderTests.swift`:

```swift
import Foundation
import Testing
@testable import iGopherBrowser

struct GopherFileLoaderTests {
    @Test("Detects known file signatures")
    func detectsKnownFileSignatures() {
        #expect(determineFileType(data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) == "png")
        #expect(determineFileType(data: Data([0xFF, 0xD8, 0xFF])) == "jpeg")
        #expect(determineFileType(data: Data("%PDF-".utf8)) == "pdf")
        #expect(determineFileType(data: Data([0x00, 0x01, 0x02])) == nil)
    }

    @Test("Chunks text files and writes a temp file")
    func chunksTextFiles() throws {
        let data = (0..<205).map { "line-\($0)" }.joined(separator: "\n").data(using: .utf8)!
        let loaded = try GopherFileLoader.loadedFile(from: data, displayName: "about.txt", parsedTypeIsText: true)

        #expect(loaded.textChunks.count == 3)
        #expect(loaded.fileURL.pathExtension == "txt")
        #expect(FileManager.default.fileExists(atPath: loaded.fileURL.path))
    }
}
```

- [ ] **Step 2: Add the loader type**

Create `iGopherBrowser/GopherFileLoader.swift`:

```swift
import Foundation
import GopherHelpers
import SwiftGopherClient

struct LoadedGopherFile {
    let fileURL: URL
    let data: Data
    let textChunks: [String]
}

struct GopherFileLoader {
    private let client = GopherClient()

    func load(_ item: gopherItem) async throws -> LoadedGopherFile {
        let response = try await client.sendRequest(
            to: item.host,
            port: item.port,
            message: "\(item.selector)\r\n"
        )
        guard var buffer = response.first?.rawData else {
            throw CocoaError(.fileReadUnknown)
        }

        var data = Data()
        while buffer.readableBytes > 0 {
            try Task.checkCancellation()
            if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                data.append(contentsOf: bytes)
            }
        }

        return try Self.loadedFile(
            from: data,
            displayName: item.message,
            parsedTypeIsText: item.parsedItemType == .text
        )
    }

    static func loadedFile(from data: Data, displayName: String, parsedTypeIsText: Bool) throws -> LoadedGopherFile {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString + ".\(parsedTypeIsText ? "txt" : determineFileType(data: data) ?? "unknown")"
        )
        try data.write(to: tempURL)

        let chunks: [String]
        if parsedTypeIsText, let string = String(data: data, encoding: .utf8) {
            let lines = string.components(separatedBy: .newlines)
            chunks = stride(from: 0, to: lines.count, by: 100).map {
                lines[$0..<min($0 + 100, lines.count)].joined(separator: "\n")
            }
        } else {
            chunks = []
        }

        return LoadedGopherFile(fileURL: tempURL, data: data, textChunks: chunks)
    }
}
```

- [ ] **Step 3: Update `FileView` to use `.task(id:)`**

Replace callback-driven `readFile(_:)` state mutation with:

```swift
@State private var loadedFile: LoadedGopherFile?
@State private var loadError: String?
private let loader = GopherFileLoader()

private var loadID: String {
    "\(item.host):\(item.port)\(item.selector)"
}
```

Attach loading to the view:

```swift
.task(id: loadID) {
    do {
        loadedFile = try await loader.load(item)
        fileURL = loadedFile?.fileURL
        downloadedData = loadedFile?.data
        fileContent = loadedFile?.textChunks ?? []
    } catch is CancellationError {
        return
    } catch {
        loadError = "Unable to fetch file due to network error."
        fileContent = [loadError ?? ""]
    }
}
```

Remove direct calls to `client.sendRequest(... completion:)` from `FileView`.

- [ ] **Step 4: Run focused tests**

Run:

```bash
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -only-testing:iGopherBrowserTests/GopherFileLoaderTests \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: file type and chunking tests pass.

- [ ] **Step 5: Commit**

```bash
git add iGopherBrowser/GopherFileLoader.swift iGopherBrowser/FileView.swift iGopherBrowserTests/GopherFileLoaderTests.swift iGopherBrowser.xcodeproj/project.pbxproj
git commit -m "refactor: make gopher file loading async"
```

---

### Task 6: Add Deterministic End-To-End Tests

**Files:**
- Create: `iGopherBrowser/LaunchConfiguration.swift`
- Modify: `iGopherBrowser/iGopherBrowserApp.swift:38-63`
- Create: `iGopherBrowserUITests/GopherFixtureServer.swift`
- Create: `iGopherBrowserUITests/BrowserEndToEndTests.swift`
- Modify: `iGopherBrowserUITests/iGopherBrowserUITests.swift`
- Modify: `iGopherBrowser.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add launch configuration for UI tests**

Create `iGopherBrowser/LaunchConfiguration.swift`:

```swift
import Foundation

enum LaunchConfiguration {
    static func apply() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting") else { return }

        UserDefaults.standard.set(true, forKey: "telemetryOptOut")
        UserDefaults.standard.set(false, forKey: "crtMode")
        UserDefaults.standard.set(true, forKey: "hasFinishedFirstRunTips")
        UserDefaults.standard.set(WhatsNewConfig.currentVersion, forKey: "lastSeenWhatsNewVersion")

        if let index = arguments.firstIndex(of: "-uiTestHomeURL"),
           arguments.indices.contains(index + 1),
           let url = URL(string: arguments[index + 1]) {
            UserDefaults.standard.set(url, forKey: "homeURL")
        }
    }
}
```

Call it at the top of `iGopherBrowserApp.init()` before TelemetryDeck configuration:

```swift
init() {
    LaunchConfiguration.apply()

    let configuration = TelemetryDeck.Config(
        appID: "400187ED-ADA9-4AB4-91F8-8825AD8FC67C")
    configuration.analyticsDisabled = UserDefaults.standard.bool(forKey: "telemetryOptOut")
    TelemetryDeck.initialize(config: configuration)
    ...
}
```

- [ ] **Step 2: Add an in-process gopher fixture server for UI tests**

Create `iGopherBrowserUITests/GopherFixtureServer.swift`:

```swift
import Foundation
import Network

final class GopherFixtureServer {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "GopherFixtureServer")

    var port: UInt16 {
        listener.port!.rawValue
    }

    init() throws {
        listener = try NWListener(using: .tcp, on: 0)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
    }

    deinit {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
            let selector = data.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .newlines) ?? "/"
            let response = Self.response(for: selector, port: self.port)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private static func response(for selector: String, port: UInt16) -> Data {
        switch selector {
        case "", "/":
            return menu([
                "iWelcome to Fixture Gopher\tfake\tlocalhost\t\(port)",
                "1Documents\t/docs\t127.0.0.1\t\(port)",
                "0About Fixture\t/about.txt\t127.0.0.1\t\(port)",
                "7Search Server\t/search\t127.0.0.1\t\(port)",
                "IImage Fixture\t/image.png\t127.0.0.1\t\(port)",
                "hHTTP Link\tURL:https://example.com\t127.0.0.1\t\(port)"
            ])
        case "/docs":
            return menu([
                "iNested directory\tfake\tlocalhost\t\(port)",
                "0Read Me\t/readme.txt\t127.0.0.1\t\(port)"
            ])
        case "/about.txt":
            return Data("About Fixture\nSwiftUI browser content\nFindable needle\n".utf8)
        case "/readme.txt":
            return Data("Nested document\n".utf8)
        case "/search\tpython":
            return menu([
                "0Python Result\t/python.txt\t127.0.0.1\t\(port)"
            ])
        case "/python.txt":
            return Data("Python search result\n".utf8)
        case "/image.png":
            return Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/luzmAAAAAABJRU5ErkJggg==")!
        default:
            return menu(["iNot found: \(selector)\tfake\tlocalhost\t\(port)"])
        }
    }

    private static func menu(_ lines: [String]) -> Data {
        Data((lines.joined(separator: "\r\n") + "\r\n.\r\n").utf8)
    }
}
```

- [ ] **Step 3: Add fixture-backed UI tests**

Create `iGopherBrowserUITests/BrowserEndToEndTests.swift`:

```swift
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
        app.buttons["home-button"].tap()

        XCTAssertTrue(app.staticTexts["Welcome to Fixture Gopher"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Documents"].exists)

        app.staticTexts["Documents"].tap()
        XCTAssertTrue(app.staticTexts["Nested directory"].waitForExistence(timeout: 5))

        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Search Server"].waitForExistence(timeout: 5))

        app.staticTexts["Search Server"].tap()
        let searchField = app.textFields["Search"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("python")
        app.buttons["Search"].tap()
        XCTAssertTrue(app.staticTexts["Python Result"].waitForExistence(timeout: 5))

        app.buttons["Back"].tap()
        app.staticTexts["About Fixture"].tap()
        XCTAssertTrue(app.staticTexts["Findable needle"].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 4: Retire or narrow the old live-network UI test**

In `iGopherBrowserUITests/iGopherBrowserUITests.swift`, either remove `testExample()` or rename it to `testLiveGopherSmoke()` and mark it skipped unless an explicit environment variable is set:

```swift
guard ProcessInfo.processInfo.environment["RUN_LIVE_GOPHER_UI_TESTS"] == "1" else {
    throw XCTSkip("Live gopher UI smoke test is opt-in; fixture-backed tests cover CI.")
}
```

- [ ] **Step 5: Run UI tests**

Run:

```bash
DERIVED_DATA=/tmp/iGopherBrowser-ui
rm -rf "$DERIVED_DATA"
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -derivedDataPath "$DERIVED_DATA" \
  -only-testing:iGopherBrowserUITests/BrowserEndToEndTests \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: the app talks only to the local fixture server and no assertions depend on public `gopher.navan.dev` content.

- [ ] **Step 6: Commit**

```bash
git add iGopherBrowser/LaunchConfiguration.swift iGopherBrowser/iGopherBrowserApp.swift iGopherBrowserUITests/GopherFixtureServer.swift iGopherBrowserUITests/BrowserEndToEndTests.swift iGopherBrowserUITests/iGopherBrowserUITests.swift iGopherBrowser.xcodeproj/project.pbxproj
git commit -m "test: add fixture-backed browser end-to-end tests"
```

---

### Task 7: Product Enhancements After The Test Bed Is Stable

**Files:**
- Modify: `iGopherBrowser/BrowserSession.swift`
- Modify: `iGopherBrowser/BrowserView.swift`
- Modify: `iGopherBrowser/BookmarksView.swift`
- Modify: `iGopherBrowser/FileView.swift`
- Add tests beside the changed behavior.

- [ ] **Step 1: Add explicit loading and error states**

Use `BrowserSession.isLoading` and `BrowserSession.errorMessage` to show a small status row above the list:

```swift
if session.isLoading {
    ProgressView()
        .controlSize(.small)
        .accessibilityIdentifier("browser-loading-indicator")
}

if let error = session.errorMessage {
    ContentUnavailableView("Unable to Load", systemImage: "exclamationmark.triangle", description: Text(error))
        .accessibilityIdentifier("browser-error-view")
}
```

Add unit tests for cancellation and stale responses in `BrowserSessionTests`.

- [ ] **Step 2: Improve bookmarks/history ergonomics**

Enhance `BookmarksHistoryView` with search/filtering and duplicate bookmark protection:

```swift
@State private var filterText = ""

private var filteredBookmarks: [Bookmark] {
    guard filterText.isEmpty == false else { return bookmarks }
    return bookmarks.filter {
        $0.title.localizedCaseInsensitiveContains(filterText) ||
        $0.urlString.localizedCaseInsensitiveContains(filterText)
    }
}
```

Add a `TextField("Filter", text: $filterText)` above the segmented picker and update tests to verify filtered results.

- [ ] **Step 3: Add cache-ready boundaries**

Do not implement a full offline cache yet. Add only a protocol boundary so a later cache can be dropped in:

```swift
protocol GopherResponseCaching {
    func cachedItems(for location: GopherLocation) -> [gopherItem]?
    func store(_ items: [gopherItem], for location: GopherLocation)
}

struct NoGopherResponseCache: GopherResponseCaching {
    func cachedItems(for location: GopherLocation) -> [gopherItem]? { nil }
    func store(_ items: [gopherItem], for location: GopherLocation) {}
}
```

Inject this into `BrowserSession` after the initial refactor is passing. Add tests proving `NoGopherResponseCache` does not alter behavior.

- [ ] **Step 4: Add command and keyboard polish**

Move macOS keyboard event monitoring out of `BrowserView.onAppear` into SwiftUI commands where possible:

```swift
.commands {
    CommandGroup(after: .textEditing) {
        Button("Find in Page") {
            NotificationCenter.default.post(name: .openFindInPage, object: nil)
        }
        .keyboardShortcut("f", modifiers: .command)
    }
}
```

Only keep AppKit event monitoring when a SwiftUI command cannot express the behavior.

- [ ] **Step 5: Verify enhancements through tests**

Run:

```bash
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  COMPILER_INDEX_STORE_ENABLE=NO

xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -only-testing:iGopherBrowserUITests/BrowserEndToEndTests \
  COMPILER_INDEX_STORE_ENABLE=NO
```

- [ ] **Step 6: Commit**

```bash
git add iGopherBrowser iGopherBrowserTests iGopherBrowserUITests iGopherBrowser.xcodeproj/project.pbxproj
git commit -m "feat: improve browser state and library workflows"
```

---

### Task 8: Final Verification Matrix

**Files:**
- Modify: `README.md`
- Optional create: `docs/testing.md`

- [ ] **Step 1: Run clean app builds**

Run:

```bash
xcodebuild build \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowser \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/iGopherBrowser-build-ios \
  COMPILER_INDEX_STORE_ENABLE=NO

xcodebuild build \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowser \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/iGopherBrowser-build-macos \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: both builds succeed. If Xcode emits passcode-protected physical device warnings, unlock/disconnect that device and rerun before recording final status.

- [ ] **Step 2: Run unit and E2E tests**

Run:

```bash
xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -derivedDataPath /tmp/iGopherBrowser-tests-ios \
  COMPILER_INDEX_STORE_ENABLE=NO

xcodebuild test \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowserUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -derivedDataPath /tmp/iGopherBrowser-ui-ios \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Expected: all deterministic unit tests and fixture-backed UI tests pass.

- [ ] **Step 3: Document the workflow**

Add `docs/testing.md`:

```markdown
# Testing iGopherBrowser

## Unit Tests

Run:

```bash
xcodebuild test -project iGopherBrowser.xcodeproj -scheme iGopherBrowserTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' COMPILER_INDEX_STORE_ENABLE=NO
```

## End-To-End Tests

End-to-end tests use an in-process gopher fixture server from the UI test bundle. They should not depend on public gopher servers.

Run:

```bash
xcodebuild test -project iGopherBrowser.xcodeproj -scheme iGopherBrowserUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' COMPILER_INDEX_STORE_ENABLE=NO
```

## Live Smoke Tests

Live gopher tests are opt-in:

```bash
RUN_LIVE_GOPHER_UI_TESTS=1 xcodebuild test -project iGopherBrowser.xcodeproj -scheme iGopherBrowserUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' COMPILER_INDEX_STORE_ENABLE=NO
```
```

- [ ] **Step 4: Commit**

```bash
git add docs/testing.md README.md
git commit -m "docs: document build and test workflow"
```

---

## Implementation Order

1. Task 1 first. It removes the current iOS unit-test blocker.
2. Task 2 next. URL parsing is small, isolated, and unlocks cleaner navigation tests.
3. Task 3 before feature work. It fixes the forward-navigation bug and makes browser behavior testable.
4. Task 4 after Task 3. Splitting the view before state extraction would move duplicated logic around without reducing risk.
5. Task 5 after Task 4. File loading is user-facing and currently callback-driven, but it is less central than core browsing.
6. Task 6 before larger product polish. Deterministic E2E tests are the safety net for bookmarks/history/search/file flows.
7. Task 7 last. Product enhancements should ride on the test bed, not precede it.
8. Task 8 before merge/PR.

## Risk Notes

- `swift-gopher` is pinned to `master` in `Package.resolved`; test determinism should not depend on live upstream behavior.
- `BrowserView.swift` currently owns too many responsibilities. Keep refactors incremental so UI does not regress while moving behavior into `BrowserSession`.
- Swift Testing should be used for unit and integration tests. XCTest remains required for UI tests.
- `GopherItemRow` should use `Button` for tappable rows and accessibility grouping; avoid adding new `onTapGesture` rows.
- Use separate DerivedData paths if multiple verification commands must run near each other.
