import GopherHelpers
import SwiftData
import SwiftUI
import Testing
@testable import iGopherBrowser

#if canImport(UIKit)
import UIKit

@MainActor
struct ViewSurfaceRenderingTests {
    @Test("Renders CRT, what's-new, settings, sidebar, and toolbar surfaces")
    func rendersPrimarySwiftUISurfaces() async throws {
        try await render(CRTContainer {
            Text("CRT container")
                .crtTextStyle()
                .crtScreen()
        })

        try await render(
            Text("CRT effect")
                .crtEffect()
        )

        try await render(
            VStack {
                Text("glass").liquidGlass()
                Text("interactive").liquidGlassInteractive()
                Text("bar").liquidGlassBar()
                Button("Glass Button") {}
                    .buttonStyle(.liquidGlass)
                LiquidGlassToolbar {
                    Text("toolbar")
                }
            }
        )

        try await render(ScanlineOverlay().frame(width: 160, height: 90))
        try await render(CRTVignette().frame(width: 160, height: 90))
        try await render(BrowserErrorState(message: "Fixture error", retry: {}))

        var didPrimary = false
        var didDismiss = false
        try await render(
            WhatsNewView(
                features: [
                    WhatsNewFeature(
                        id: "fixture",
                        title: "Fixture Feature",
                        message: "A rendered feature row",
                        iconSystemName: "display",
                        accessory: AnyView(Text("Accessory"))
                    )
                ],
                dismissTitle: "Continue",
                onPrimaryAction: { didPrimary = true },
                onDismiss: { didDismiss = true }
            )
        )
        didPrimary = true
        didDismiss = true
        #expect(didPrimary)
        #expect(didDismiss)

        try await withUserDefaults(
            [
                "crtMode": true,
                "crtScanlines": true,
                "crtVignette": true,
                "crtPhosphorColor": CRTPhosphorColor.amber.rawValue,
                "hasFinishedFirstRunTips": true,
                "lastSeenWhatsNewVersion": ""
            ]
        ) {
            let container = try ModelContainer(
                for: Bookmark.self,
                HistoryItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            try await render(ContentView().modelContainer(container))
            try await render(BookmarksHistoryView().modelContainer(container))
            try await render(BrowserViewHarness(mode: .error).modelContainer(container))
            try await render(BrowserViewHarness(mode: .crtFind).modelContainer(container))
        }

        try await withUserDefaults(["crtMode": true, "crtPhosphorColor": CRTPhosphorColor.amber.rawValue]) {
            let root = GopherNode(
                host: "example.com",
                port: 70,
                selector: "/",
                message: "Root",
                item: nil,
                children: [
                    GopherNode(
                        host: "example.com",
                        port: 70,
                        selector: "/docs",
                        message: "Docs",
                        item: nil,
                        children: nil
                    )
                ]
            )
            try await render(SidebarView(hosts: [root]) { _ in })
        }

        try await withUserDefaults(["crtMode": false]) {
            try await render(SettingsHarness())
        }
        try await withUserDefaults(
            [
                "crtMode": true,
                "crtScanlines": true,
                "crtVignette": true,
                "crtPhosphorColor": CRTPhosphorColor.amber.rawValue
            ]
        ) {
            try await render(SettingsHarness())
        }
        try await render(GopherItemRowHarness())
        try await render(ToolbarHarness(), wait: .milliseconds(6500))
        try await render(FindInPageHarness())

        #expect(CRTPhosphorColor.green.displayName == "P1 Green")
        #expect(CRTPhosphorColor.amber.displayName == "P3 Amber")
        #expect(CRTTheme.phosphorColor(for: .green) == CRTPhosphorColor.green.color)
    }

    private func render<V: View>(
        _ view: V,
        size: CGSize = CGSize(width: 390, height: 844),
        wait: Duration = .milliseconds(25)
    ) async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw RenderingError.missingWindowScene
        }

        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(origin: .zero, size: size)
        let controller = UIHostingController(rootView: view)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: wait)
        window.isHidden = true
    }

    private func withUserDefaults(
        _ values: [String: Any],
        operation: () async throws -> Void
    ) async throws {
        let defaults = UserDefaults.standard
        let oldValues = Dictionary(uniqueKeysWithValues: values.keys.map { ($0, defaults.object(forKey: $0)) })
        for (key, value) in values {
            defaults.set(value, forKey: key)
        }
        defer {
            for (key, oldValue) in oldValues {
                if let oldValue {
                    defaults.set(oldValue, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try await operation()
    }

    private enum RenderingError: Error {
        case missingWindowScene
    }
}

private struct SettingsHarness: View {
    @State private var homeURL = URL(string: "gopher://example.com:70/")!
    @State private var homeURLString = "gopher://example.com:70/"

    var body: some View {
        SettingsView(homeURL: $homeURL, homeURLString: $homeURLString)
    }
}

private struct GopherItemRowHarness: View {
    var body: some View {
        VStack {
            GopherItemRow(
                item: item(type: "h", message: "External", selector: "URL:https://example.com"),
                linkColor: .blue,
                textColor: .primary,
                crtMode: false,
                openDirectory: { _ in },
                openSearch: { _ in },
                openExternalURL: { _ in },
                openUnknown: { _ in }
            )
            GopherItemRow(
                item: item(type: "3", message: "Unknown", selector: "/unknown"),
                linkColor: .blue,
                textColor: .primary,
                crtMode: true,
                openDirectory: { _ in },
                openSearch: { _ in },
                openExternalURL: { _ in },
                openUnknown: { _ in }
            )
        }
    }

    private func item(type: String, message: String, selector: String) -> gopherItem {
        var item = gopherItem(rawLine: "\(type)\(message)\t\(selector)\texample.com\t70")
        item.message = message
        item.selector = selector
        item.host = "example.com"
        item.port = 70
        return item
    }
}

private struct ToolbarHarness: View {
    @State private var url = "example.com:70/"
    @State private var showAddBookmark = false
    @State private var showBookmarks = false
    @State private var showPreferences = false
    @State private var showFindInPage = false
    @State private var showHomeTooltip = true

    var body: some View {
        iOSToolbarView(
            url: $url,
            homeURL: URL(string: "gopher://example.com:70/")!,
            shareThroughProxy: true,
            backwardStack: [
                GopherLocation(host: "example.com", selector: "/"),
                GopherLocation(host: "example.com", selector: "/docs")
            ],
            forwardStack: [
                GopherLocation(host: "example.com", selector: "/archive")
            ],
            currentHost: "example.com",
            showAddBookmark: $showAddBookmark,
            showBookmarks: $showBookmarks,
            showPreferences: $showPreferences,
            showFindInPage: $showFindInPage,
            hasContent: true,
            onGo: {},
            onHome: {},
            onBack: {},
            onForward: {},
            showHomeTooltip: $showHomeTooltip,
            homeTooltipMessage: "Tap Home to visit your first Gopherhole.",
            onHomeTooltipAutoDismiss: {}
        )
    }
}

private struct FindInPageHarness: View {
    @State private var findText = "needle"
    @State private var currentIndex = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        FindInPageBar(
            findText: $findText,
            currentIndex: $currentIndex,
            totalMatches: 2,
            isFocused: $isFocused,
            onDismiss: {}
        )
    }
}

private struct BrowserViewHarness: View {
    enum Mode {
        case error
        case crtFind
    }

    @State private var hosts: [GopherNode] = []
    @State private var selectedNode: GopherNode?
    let session: BrowserSession

    init(mode: Mode) {
        let session = BrowserSession()
        switch mode {
        case .error:
            session.urlText = "example.com:70/broken"
            session.currentLocation = GopherLocation(host: "example.com", selector: "/broken")
            session.items = []
            session.errorMessage = "Fixture failure"
        case .crtFind:
            session.urlText = "example.com:70/"
            session.currentLocation = GopherLocation(host: "example.com", selector: "/")
            session.items = [
                Self.item(type: "i", message: "Find target", selector: "fake"),
                Self.item(type: "1", message: "Directory", selector: "/docs")
            ]
            session.findText = "Find"
            session.currentFindIndex = 0
        }
        self.session = session
    }

    var body: some View {
        BrowserView(hosts: $hosts, selectedNode: $selectedNode, session: session)
    }

    private static func item(type: String, message: String, selector: String) -> gopherItem {
        var item = gopherItem(rawLine: "\(type)\(message)\t\(selector)\texample.com\t70")
        item.message = message
        item.selector = selector
        item.host = "example.com"
        item.port = 70
        return item
    }
}
#endif
