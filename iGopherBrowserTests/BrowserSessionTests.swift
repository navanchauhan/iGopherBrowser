import Foundation
import GopherHelpers
import Testing
@testable import iGopherBrowser

@MainActor
struct BrowserSessionTests {
    @Test("Forward uses the forward stack, not the back stack")
    func forwardUsesForwardStack() async {
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
        let fetcher = MockGopherFetcher(itemsBySelector: [:])
        let session = BrowserSession(fetcher: fetcher)

        await session.load(GopherLocation(host: "example.com", selector: "/search"))

        #expect(session.searchContext == SearchContext(host: "example.com", port: 70, selector: "/search"))
        #expect(session.items.isEmpty)
        #expect(fetcher.requestedSelectors.isEmpty)
    }

    @Test("Newer navigation wins over stale responses")
    func newerNavigationWins() async {
        let fetcher = MockGopherFetcher(
            itemsBySelector: [
                "/slow": [FixtureItems.info("Slow")],
                "/fast": [FixtureItems.info("Fast")]
            ],
            delayedSelectors: ["/slow"]
        )
        let session = BrowserSession(fetcher: fetcher)

        let slow = Task {
            await session.load(GopherLocation(host: "example.com", selector: "/slow"))
        }
        try? await Task.sleep(for: .milliseconds(10))
        await session.load(GopherLocation(host: "example.com", selector: "/fast"))
        await slow.value

        #expect(session.items.map(\.message) == ["Fast"])
        #expect(session.currentLocation?.selector == "/fast")
    }

    @Test("No-op cache leaves fetching behavior unchanged")
    func noCacheDoesNotChangeBehavior() async {
        let fetcher = MockGopherFetcher(itemsBySelector: [
            "/": [FixtureItems.info("Fresh")]
        ])
        let session = BrowserSession(fetcher: fetcher, cache: NoGopherResponseCache())

        await session.load(GopherLocation(host: "example.com", selector: "/"))

        #expect(session.items.map(\.message) == ["Fresh"])
    }

    @Test("Fetch errors clear items and expose an error state")
    func fetchErrorClearsItems() async {
        let fetcher = MockGopherFetcher(itemsBySelector: [:], throwingSelectors: ["/broken"])
        let session = BrowserSession(fetcher: fetcher)

        await session.load(GopherLocation(host: "example.com", selector: "/broken"))

        #expect(session.items.isEmpty)
        #expect(session.errorMessage?.isEmpty == false)
        #expect(session.isLoading == false)
    }

    @Test("Reloading host root replaces sidebar children instead of duplicating")
    func rootReloadReplacesSidebarChildren() async {
        let fetcher = MockGopherFetcher(itemsBySelector: [
            "/": [
                FixtureItems.directory("Posts", selector: "/posts"),
                FixtureItems.search("Search Server", selector: "/search")
            ]
        ])
        let session = BrowserSession(fetcher: fetcher)

        await session.load(GopherLocation(host: "example.com", selector: "/"))
        await session.load(GopherLocation(host: "example.com", selector: "/"))

        #expect(session.hosts.count == 1)
        #expect(session.hosts.first?.children?.map(\.message) == ["Posts", "Search Server"])
    }
}

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

    static func search(_ message: String, selector: String) -> gopherItem {
        var item = gopherItem(rawLine: "7\(message)\t\(selector)\texample.com\t70")
        item.message = message
        item.host = "example.com"
        item.port = 70
        item.selector = selector
        return item
    }
}

private final class MockGopherFetcher: GopherFetching {
    var itemsBySelector: [String: [gopherItem]]
    var delayedSelectors: Set<String>
    var throwingSelectors: Set<String>
    private(set) var requestedSelectors: [String] = []

    init(
        itemsBySelector: [String: [gopherItem]],
        delayedSelectors: Set<String> = [],
        throwingSelectors: Set<String> = []
    ) {
        self.itemsBySelector = itemsBySelector
        self.delayedSelectors = delayedSelectors
        self.throwingSelectors = throwingSelectors
    }

    func fetch(_ location: GopherLocation) async throws -> [gopherItem] {
        requestedSelectors.append(location.selector)
        if throwingSelectors.contains(location.selector) {
            throw URLError(.cannotConnectToHost)
        }
        if delayedSelectors.contains(location.selector) {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return itemsBySelector[location.selector] ?? []
    }
}
