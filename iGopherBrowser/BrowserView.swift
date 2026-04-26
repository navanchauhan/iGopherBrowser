//
//  BrowserView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//

import GopherHelpers
import SwiftData
import SwiftUI
import TelemetryDeck
#if os(macOS)
import AppKit
#endif

func openURL(url: URL) {
    #if os(OSX)
        NSWorkspace.shared.open(url)
    #else
        UIApplication.shared.open(url)
    #endif
}

#if canImport(UIKit)
    extension View {
        func hideKeyboard() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
#endif

struct BrowserView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("homeURL") var homeURL: URL = URL(string: "gopher://gopher.navan.dev:70/")!
    @AppStorage("accentColour", store: .standard) var accentColour: Color = Color(.blue)
    @AppStorage("linkColour", store: .standard) var linkColour: Color = Color(.white)
    @AppStorage("shareThroughProxy", store: .standard) var shareThroughProxy: Bool = true
    @AppStorage("crtMode") var crtMode: Bool = false
    @AppStorage("crtPhosphorColor") var crtPhosphorColorRaw: String = CRTPhosphorColor.green.rawValue
    @AppStorage("hasFinishedFirstRunTips") var hasFinishedFirstRunTips: Bool = false
    @AppStorage("lastSeenWhatsNewVersion") var lastSeenWhatsNewVersion: String = ""

    // CRT-aware colors
    private var crtPhosphorColor: Color {
        (CRTPhosphorColor(rawValue: crtPhosphorColorRaw) ?? .green).color
    }

    private var effectiveLinkColor: Color {
        crtMode ? crtPhosphorColor : linkColour
    }

    private var effectiveTextColor: Color {
        crtMode ? crtPhosphorColor : .primary
    }

    @State var homeURLString = "gopher://gopher.navan.dev:70/"

    @State private var session = BrowserSession()

    @Binding public var hosts: [GopherNode]
    @Binding var selectedNode: GopherNode?

    @MainActor
    init(hosts: Binding<[GopherNode]>, selectedNode: Binding<GopherNode?>) {
        self.init(hosts: hosts, selectedNode: selectedNode, session: BrowserSession())
    }

    @MainActor
    init(
        hosts: Binding<[GopherNode]>,
        selectedNode: Binding<GopherNode?>,
        session: BrowserSession
    ) {
        self._hosts = hosts
        self._selectedNode = selectedNode
        self._session = State(initialValue: session)
    }

    @State private var searchText: String = ""
    @State private var showSearchInput = false
    @State var selectedSearchItem: Int?

    @State private var showPreferences = false
    @State private var showBookmarks = false
    @State private var showAddBookmark = false

    @Namespace var topID
    @State private var scrollToTop: Bool = false

    @State private var showHomeTooltip: Bool = false

    @FocusState private var isURLFocused: Bool

    // Find in page
    @State private var showFindInPage = false
    @FocusState private var isFindFocused: Bool

    private let homeTooltipMessage = "Tap Home to visit your first Gopherhole."

    private var currentHost: String {
        session.currentLocation?.host ?? ""
    }

    private var currentPort: Int {
        session.currentLocation?.port ?? 70
    }

    private var currentSelector: String {
        session.currentLocation?.selector ?? ""
    }

    var body: some View {
        @Bindable var session = session

        NavigationStack {
            VStack(spacing: 0) {
                if session.isLoading && session.items.isEmpty {
                    BrowserLoadingState()
                } else if let errorMessage = session.errorMessage, session.items.isEmpty {
                    BrowserErrorState(message: errorMessage) {
                        performGopherRequest(clearForward: false)
                    }
                } else if session.items.count >= 1 {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(session.items.enumerated()), id: \.offset) { idx, item in
                                GopherItemRow(
                                    item: item,
                                    linkColor: effectiveLinkColor,
                                    textColor: effectiveTextColor,
                                    crtMode: crtMode,
                                    openDirectory: { item in
                                        performGopherRequest(
                                            host: item.host, port: item.port,
                                            selector: item.selector)
                                        #if canImport(UIKit)
                                            hideKeyboard()
                                        #endif
                                    },
                                    openSearch: { _ in
                                        #if canImport(UIKit)
                                            hideKeyboard()
                                        #endif
                                        self.selectedSearchItem = idx
                                        self.showSearchInput = true
                                    },
                                    openExternalURL: { url in
                                        openURL(url: url)
                                    },
                                    openUnknown: { item in
                                        TelemetryDeck.signal(
                                            "applicationBrowsedUnknown",
                                            parameters: [
                                                "gopherURL":
                                                    "\(item.host):\(item.port)\(item.selector)"
                                            ])
                                        performGopherRequest(
                                            host: item.host, port: item.port,
                                            selector: item.selector)
                                    }
                                )
                                .id(idx)
                                .listRowBackground(rowBackgroundColor(for: idx))
                            }
                        }
                        .scrollContentBackground(crtMode ? .hidden : .automatic)
                        .background(crtMode ? Color.clear : Color.clear)
                        .clipShape(.rect(cornerRadius: 10))
                        .onChange(of: scrollToTop) { _, _ in
                            // TODO: Cleanup
                            proxy.scrollTo(0, anchor: .top)
                        }
                        .onChange(of: selectedSearchItem) { _, newValue in
                            if newValue != nil {
                                self.showSearchInput = true
                            }
                        }
                        .onChange(of: session.currentFindIndex) { _, newIndex in
                            if !session.findMatches.isEmpty && newIndex < session.findMatches.count {
                                withAnimation {
                                    proxy.scrollTo(session.findMatches[newIndex], anchor: .center)
                                }
                            }
                        }
                        .onChange(of: session.findText) { _, _ in
                            session.currentFindIndex = 0
                            if !session.findMatches.isEmpty {
                                withAnimation {
                                    proxy.scrollTo(session.findMatches[0], anchor: .center)
                                }
                            }
                        }
                        .safeAreaInset(edge: .top) {
                            if showFindInPage {
                                FindInPageBar(
                                    findText: $session.findText,
                                    currentIndex: $session.currentFindIndex,
                                    totalMatches: session.findMatches.count,
                                    isFocused: $isFindFocused,
                                    onDismiss: {
                                        showFindInPage = false
                                        session.findText = ""
                                    }
                                )
                            }
                        }
                    }
                    .sheet(isPresented: $showSearchInput, onDismiss: {
                        // Reset contexts so tapping the same item or deep-link works again
                        self.selectedSearchItem = nil
                        self.session.searchContext = nil
                    }) {
                        if let index = selectedSearchItem, session.items.indices.contains(index) {
                            let searchItem = session.items[index]
                            SearchInputView(
                                host: searchItem.host,
                                port: searchItem.port,
                                selector: searchItem.selector,
                                searchText: $searchText,
                                onSearch: { query in
                                    performGopherRequest(
                                        host: searchItem.host, port: searchItem.port,
                                        selector: "\(searchItem.selector)\t\(query)")
                                    showSearchInput = false
                                }
                            )
                        } else if let ctx = session.searchContext {
                            SearchInputView(
                                host: ctx.host,
                                port: ctx.port,
                                selector: ctx.selector,
                                searchText: $searchText,
                                onSearch: { query in
                                    performGopherRequest(
                                        host: ctx.host, port: ctx.port,
                                        selector: "\(ctx.selector)\t\(query)")
                                    showSearchInput = false
                                }
                            )
                        } else {
                            VStack {
                                Text("Weird bug. Please Dismiss -> Press Go -> Try Again")
                                Button("Dismiss") {
                                    self.showSearchInput = false
                                }.onAppear {
                                    TelemetryDeck.signal(
                                        "applicationSearchError", parameters: ["gopherURL": "\(session.urlText)"]
                                    )
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                    Text("Welcome to iGopher Browser")
                    Spacer()
                }
                #if os(iOS)
                    iOSToolbarView(
                        url: $session.urlText,
                        homeURL: homeURL,
                        shareThroughProxy: shareThroughProxy,
                        backwardStack: session.backwardStack,
                        forwardStack: session.forwardStack,
                        currentHost: currentHost,
                        showAddBookmark: $showAddBookmark,
                        showBookmarks: $showBookmarks,
                        showPreferences: $showPreferences,
                        showFindInPage: $showFindInPage,
                        hasContent: !session.items.isEmpty,
                        onGo: {
                            TelemetryDeck.signal(
                                "applicationClickedGo", parameters: ["gopherURL": "\(session.urlText)"])
                            performGopherRequest(clearForward: false)
                        },
                        onHome: {
                            handleHomeTap()
                        },
                        onBack: { goBack() },
                        onForward: { goForward() },
                        showHomeTooltip: $showHomeTooltip,
                        homeTooltipMessage: homeTooltipMessage,
                        onHomeTooltipAutoDismiss: { dismissHomeTooltip() }
                    )
                #else
                    macOSToolbarView(
                        url: $session.urlText,
                        isURLFocused: $isURLFocused,
                        homeURL: homeURL,
                        shareThroughProxy: shareThroughProxy,
                        backwardStack: session.backwardStack,
                        forwardStack: session.forwardStack,
                        currentHost: currentHost,
                        showAddBookmark: $showAddBookmark,
                        showBookmarks: $showBookmarks,
                        showPreferences: $showPreferences,
                        onGo: {
                            TelemetryDeck.signal(
                                "applicationClickedGo", parameters: ["gopherURL": "\(session.urlText)"])
                            performGopherRequest(clearForward: false)
                        },
                        onHome: {
                            handleHomeTap()
                        },
                        onBack: { goBack() },
                        onForward: { goForward() },
                        showHomeTooltip: $showHomeTooltip,
                        homeTooltipMessage: homeTooltipMessage,
                        onHomeTooltipAutoDismiss: { dismissHomeTooltip() }
                    )
                #endif
            }
        }
        .onChange(of: selectedNode) { _, newValue in
            if let node = newValue {
                performGopherRequest(host: node.host, port: node.port, selector: node.selector)
            }
        }
        .onChange(of: session.searchContext) { _, newValue in
            if newValue != nil {
                searchText = ""
                selectedSearchItem = nil
                showSearchInput = true
            }
        }
        .onOpenURL { gopherURL in
            self.session.urlText = gopherURL.absoluteString
            performGopherRequest()
        }
        .sheet(
            isPresented: $showPreferences,
            onDismiss: {
                print("badm", homeURL, homeURLString)
                if let url = URL(string: homeURLString) {
                    self.homeURL = url
                }
            }
        ) {
            #if os(macOS)
                SettingsView()
            #else
                SettingsView(homeURL: $homeURL, homeURLString: $homeURLString)
            #endif
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksHistoryView { host, port, selector in
                performGopherRequest(host: host, port: port, selector: selector)
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.automatic)
            #endif
        }
        .sheet(isPresented: $showAddBookmark) {
            AddBookmarkView(
                host: currentHost,
                port: currentPort,
                selector: currentSelector
            )
            #if os(iOS)
            .presentationDetents([.medium])
            .presentationDragIndicator(.automatic)
            #endif
        }
        .tint(accentColour)
        
        .onAppear {
            session.hosts = hosts
            if !hasFinishedFirstRunTips && !showHomeTooltip {
                withAnimation(.spring()) {
                    showHomeTooltip = true
                }
            }
            #if os(OSX)
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Command+F for Find in Page
                if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.option) && event.charactersIgnoringModifiers == "f" {
                    if !session.items.isEmpty {
                        showFindInPage = true
                    }
                    return nil
                }
                // Option+Command+F for URL focus
                if event.modifierFlags.contains([.option, .command]) && event.charactersIgnoringModifiers == "f" {
                    isURLFocused = true
                    return nil
                }
                // Escape to dismiss find bar or unfocus URL
                if event.keyCode == 53 {
                    if showFindInPage {
                        showFindInPage = false
                        session.findText = ""
                    } else {
                        isURLFocused = false
                    }
                    return nil
                }
                return event
            }
            #endif
        }
        .background {
            // Hidden button for Command+F keyboard shortcut on iOS
            Button("") {
                if !session.items.isEmpty {
                    showFindInPage = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
        }
    }
    
    private func goBack() {
        Task {
            await session.goBack()
            syncSessionOutputs()
            saveCurrentLocationToHistory()
        }
    }
    
    private func goForward() {
        Task {
            await session.goForward()
            syncSessionOutputs()
            saveCurrentLocationToHistory()
        }
    }

    private func handleHomeTap() {
        if showHomeTooltip {
            withAnimation(.spring()) {
                showHomeTooltip = false
            }
        }
        completeFirstRunExperience()
        TelemetryDeck.signal(
            "applicationClickedHome", parameters: ["gopherURL": "\(session.urlText)"])
        performGopherRequest(
            host: homeURL.host ?? "gopher.navan.dev",
            port: homeURL.port ?? 70,
            selector: homeURL.path)
    }

    private func dismissHomeTooltip() {
        if showHomeTooltip {
            withAnimation(.spring()) {
                showHomeTooltip = false
            }
        }
        completeFirstRunExperience()
    }

    private func completeFirstRunExperience() {
        guard !hasFinishedFirstRunTips else { return }
        hasFinishedFirstRunTips = true
        lastSeenWhatsNewVersion = WhatsNewConfig.currentVersion
    }

    private func performGopherRequest(
        host: String = "", port: Int = -1, selector: String = "", clearForward: Bool = true
    ) {
        let location: GopherLocation
        if host.isEmpty {
            location = GopherLocation(session.urlText)
        } else {
            location = GopherLocation(
                host: host,
                port: port == -1 ? 70 : port,
                selector: selector
            )
        }

        Task {
            await session.load(location, clearForward: clearForward)
            syncSessionOutputs()
            if let errorMessage = session.errorMessage {
                TelemetryDeck.signal(
                    "applicationRequestError",
                    parameters: ["gopherURL": "\(session.urlText)", "errorMessage": errorMessage])
            } else {
                saveCurrentLocationToHistory()
                scrollToTop.toggle()
            }
        }
    }
    
    private func rowBackgroundColor(for idx: Int) -> Color? {
        // Find highlight takes priority
        if session.findMatches.contains(idx) {
            if crtMode {
                if session.findMatches.firstIndex(of: idx) == session.currentFindIndex {
                    return crtPhosphorColor.opacity(0.3)
                }
                return crtPhosphorColor.opacity(0.15)
            } else {
                if session.findMatches.firstIndex(of: idx) == session.currentFindIndex {
                    return Color.yellow.opacity(0.5)
                }
                return Color.yellow.opacity(0.2)
            }
        }

        return crtMode ? CRTTheme.screenBackground : nil
    }

    private func syncSessionOutputs() {
        hosts = session.hosts
    }

    private func saveCurrentLocationToHistory() {
        guard let location = session.currentLocation, session.errorMessage == nil else { return }

        let historyItem = HistoryItem(
            title: "\(location.host)\(location.selector)",
            host: location.host,
            port: location.port,
            selector: location.selector
        )
        modelContext.insert(historyItem)
    }

}

private struct BrowserLoadingState: View {
    var body: some View {
        Spacer()
        ProgressView("Loading Gopher page")
            .accessibilityIdentifier("browser-loading-state")
        Spacer()
    }
}

struct BrowserErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        Spacer()
        ContentUnavailableView {
            Label("Unable to Load Page", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
                .accessibilityIdentifier("retry-button")
        }
        .accessibilityIdentifier("browser-error-state")
        Spacer()
    }
}

#if os(iOS)
struct iOSToolbarView: View {
    @Binding var url: String
    let homeURL: URL
    let shareThroughProxy: Bool
    let backwardStack: [GopherLocation]
    let forwardStack: [GopherLocation]
    let currentHost: String
    @Binding var showAddBookmark: Bool
    @Binding var showBookmarks: Bool
    @Binding var showPreferences: Bool
    @Binding var showFindInPage: Bool
    let hasContent: Bool
    let onGo: () -> Void
    let onHome: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    @Binding var showHomeTooltip: Bool
    let homeTooltipMessage: String
    let onHomeTooltipAutoDismiss: () -> Void

    private var shareURL: URL {
        shareThroughProxy
            ? URL(string: "https://gopher.navan.dev/\(url)")!
            : URL(string: "gopher://\(url)")!
    }

    var body: some View {
        VStack(spacing: 0) {
            // URL bar with Go button
            HStack(spacing: 8) {
                TextField("Enter URL", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .textContentType(.URL)
                    .accessibilityIdentifier("url-field")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                                .glassEffect(in: .rect(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        }
                    }

                Button(action: onGo) {
                    Text("Go")
                        .fontWeight(.medium)
                }
                .keyboardShortcut(.defaultAction)
                .modifier(GoButtonStyle())
                .accessibilityIdentifier("go-button")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Bottom toolbar - cleaner design
            HStack(spacing: 0) {
                // Navigation group
                HStack(spacing: 4) {
                    navButton(icon: "chevron.left", accessibilityLabel: "Back", identifier: "back-button", action: onBack)
                        .disabled(backwardStack.count < 2)

                    navButton(icon: "chevron.right", accessibilityLabel: "Forward", identifier: "forward-button", action: onForward)
                        .disabled(forwardStack.isEmpty)
                }
                .modifier(ToolbarGroupStyle())

                Spacer()

                // Center actions - Home & Bookmark
                HStack(spacing: 4) {
                    HomeButtonTooltipWrapper(
                        isVisible: $showHomeTooltip,
                        message: homeTooltipMessage,
                        onAutoDismiss: onHomeTooltipAutoDismiss
                    ) {
                        navButton(icon: "house", accessibilityLabel: "Home", identifier: "home-button", action: onHome)
                    }

                    Button(action: { showAddBookmark = true }) {
                        Image(systemName: currentHost.isEmpty ? "bookmark" : "bookmark.fill")
                            .font(.system(size: 18))
                            .frame(width: 44, height: 36)
                    }
                    .disabled(currentHost.isEmpty)
                    .accessibilityLabel("Add Bookmark")
                    .accessibilityIdentifier("add-bookmark-button")
                }
                .modifier(ToolbarGroupStyle())

                Spacer()

                // Right actions group
                HStack(spacing: 4) {
                    navButton(icon: "clock.arrow.circlepath", accessibilityLabel: "Bookmarks and History", identifier: "bookmarks-history-button", action: { showBookmarks = true })

                    Menu {
                        Button(action: { showFindInPage = true }) {
                            Label("Find in Page", systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(!hasContent)
                        .accessibilityIdentifier("find-in-page-button")

                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(action: { showPreferences = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                        .accessibilityIdentifier("settings-button")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .frame(width: 44, height: 36)
                    }
                    .accessibilityIdentifier("browser-menu-button")
                }
                .modifier(ToolbarGroupStyle())
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func navButton(
        icon: String,
        accessibilityLabel: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 44, height: 36)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Button Styles for iOS Toolbar

private struct GoButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.liquidGlass)
        } else {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 8))
        }
    }
}

private struct ToolbarGroupStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(in: .capsule)
        } else {
            content
                .padding(.horizontal, 4)
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}

#endif

#if os(macOS) || os(visionOS)
struct macOSToolbarView: View {
    @Binding var url: String
    var isURLFocused: FocusState<Bool>.Binding
    let homeURL: URL
    let shareThroughProxy: Bool
    let backwardStack: [GopherLocation]
    let forwardStack: [GopherLocation]
    let currentHost: String
    @Binding var showAddBookmark: Bool
    @Binding var showBookmarks: Bool
    @Binding var showPreferences: Bool
    let onGo: () -> Void
    let onHome: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    @Binding var showHomeTooltip: Bool
    let homeTooltipMessage: String
    let onHomeTooltipAutoDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            navigationButtons
            urlField
            actionButtons
            goButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var navigationButtons: some View {
        #if os(visionOS)
            HStack(spacing: 8) {
                HomeButtonTooltipWrapper(
                    isVisible: $showHomeTooltip,
                    message: homeTooltipMessage,
                    onAutoDismiss: onHomeTooltipAutoDismiss
                ) {
                            Button(action: onHome) {
                                Label("Home", systemImage: "house")
                                    .labelStyle(.iconOnly)
                            }
                            .keyboardShortcut("r", modifiers: [.command])
                            .accessibilityIdentifier("home-button")
                        }

                        Button(action: { showPreferences = true }) {
                            Label("Settings", systemImage: "gear")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityIdentifier("settings-button")

                        Button(action: onBack) {
                            Label("Back", systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                        }
                        .keyboardShortcut("[", modifiers: [.command])
                        .disabled(backwardStack.count < 2)
                        .accessibilityIdentifier("back-button")

                        Button(action: onForward) {
                            Label("Forward", systemImage: "chevron.right")
                                .labelStyle(.iconOnly)
                        }
                        .keyboardShortcut("]", modifiers: [.command])
                        .disabled(forwardStack.isEmpty)
                        .accessibilityIdentifier("forward-button")
            }
        #else
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        HomeButtonTooltipWrapper(
                            isVisible: $showHomeTooltip,
                            message: homeTooltipMessage,
                            onAutoDismiss: onHomeTooltipAutoDismiss
                        ) {
                            Button(action: onHome) {
                                Label("Home", systemImage: "house")
                                    .labelStyle(.iconOnly)
                            }
                            .glassEffect(.regular.interactive())
                            .keyboardShortcut("r", modifiers: [.command])
                            .accessibilityIdentifier("home-button")
                        }

                        Button(action: onBack) {
                            Label("Back", systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                        }
                        .glassEffect(.regular.interactive())
                        .keyboardShortcut("[", modifiers: [.command])
                        .disabled(backwardStack.count < 2)
                        .accessibilityIdentifier("back-button")

                        Button(action: onForward) {
                            Label("Forward", systemImage: "chevron.right")
                                .labelStyle(.iconOnly)
                        }
                        .glassEffect(.regular.interactive())
                        .keyboardShortcut("]", modifiers: [.command])
                        .disabled(forwardStack.isEmpty)
                        .accessibilityIdentifier("forward-button")
                    }
                }
            } else {
                HStack(spacing: 4) {
                    HomeButtonTooltipWrapper(
                        isVisible: $showHomeTooltip,
                        message: homeTooltipMessage,
                        onAutoDismiss: onHomeTooltipAutoDismiss
                    ) {
                        Button(action: onHome) {
                            Label("Home", systemImage: "house")
                                .labelStyle(.iconOnly)
                        }
                        .keyboardShortcut("r", modifiers: [.command])
                        .accessibilityIdentifier("home-button")
                    }

                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                    }
                    .keyboardShortcut("[", modifiers: [.command])
                    .disabled(backwardStack.count < 2)
                    .accessibilityIdentifier("back-button")

                    Button(action: onForward) {
                        Label("Forward", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                    }
                    .keyboardShortcut("]", modifiers: [.command])
                    .disabled(forwardStack.isEmpty)
                    .accessibilityIdentifier("forward-button")
                }
            }
        #endif
    }

    @ViewBuilder
    private var urlField: some View {
        #if os(visionOS)
            TextField("Enter a URL", text: $url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .focused(isURLFocused)
                .padding(10)
                .accessibilityIdentifier("url-field")
        #else
            if #available(macOS 26.0, *) {
                TextField("Enter a URL", text: $url)
                    .focused(isURLFocused)
                    .padding(10)
                    .glassEffect(in: .rect(cornerRadius: 8))
                    .accessibilityIdentifier("url-field")
            } else {
                TextField("Enter a URL", text: $url)
                    .focused(isURLFocused)
                    .padding(10)
                    .accessibilityIdentifier("url-field")
            }
        #endif
    }

    @ViewBuilder
    private var actionButtons: some View {
        #if os(visionOS)
            HStack(spacing: 8) {
                Button(action: { showAddBookmark = true }) {
                    Label("Add Bookmark", systemImage: "bookmark.fill")
                        .labelStyle(.iconOnly)
                }
                .disabled(currentHost.isEmpty)
                .accessibilityIdentifier("add-bookmark-button")

                Button(action: { showBookmarks = true }) {
                    Label("Bookmarks", systemImage: "book")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("bookmarks-history-button")

                shareLink
            }
        #else
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: { showAddBookmark = true }) {
                            Label("Add Bookmark", systemImage: "bookmark.fill")
                                .labelStyle(.iconOnly)
                        }
                        .glassEffect(.regular.interactive())
                        .disabled(currentHost.isEmpty)
                        .accessibilityIdentifier("add-bookmark-button")

                        Button(action: { showBookmarks = true }) {
                            Label("Bookmarks", systemImage: "book")
                                .labelStyle(.iconOnly)
                        }
                        .glassEffect(.regular.interactive())
                        .accessibilityIdentifier("bookmarks-history-button")

                        shareLink
                    }
                }
            } else {
                HStack {
                    Button(action: { showAddBookmark = true }) {
                        Label("Add Bookmark", systemImage: "bookmark.fill")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(currentHost.isEmpty)
                    .accessibilityIdentifier("add-bookmark-button")

                    Button(action: { showBookmarks = true }) {
                        Label("Bookmarks", systemImage: "book")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityIdentifier("bookmarks-history-button")

                    shareLink
                }
            }
        #endif
    }

    @ViewBuilder
    private var shareLink: some View {
        let shareURL = shareThroughProxy
            ? URL(string: "https://gopher.navan.dev/\(url)")!
            : URL(string: "gopher://\(url)")!

        #if os(visionOS)
            ShareLink(item: shareURL) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
        #else
            if #available(macOS 26.0, *) {
                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .glassEffect(.regular.interactive())
            } else {
                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
            }
        #endif
    }

    @ViewBuilder
    private var goButton: some View {
        Button("Go", action: onGo)
            .buttonStyle(.liquidGlass)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("go-button")
    }
}
#endif

struct HomeButtonTooltipWrapper<Content: View>: View {
    @Binding var isVisible: Bool
    let message: String
    let onAutoDismiss: () -> Void
    private let content: () -> Content
    @State private var didScheduleDismiss = false

    init(
        isVisible: Binding<Bool>,
        message: String,
        onAutoDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isVisible = isVisible
        self.message = message
        self.onAutoDismiss = onAutoDismiss
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            content()

            if isVisible {
                HomeTooltipCard(message: message)
                    .offset(y: -72)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        scheduleAutoDismiss()
                    }
            }
        }
    }

    private func scheduleAutoDismiss() {
        guard !didScheduleDismiss else { return }
        didScheduleDismiss = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if isVisible {
                withAnimation(.spring()) {
                    isVisible = false
                }
                onAutoDismiss()
            }
        }
    }
}

private struct HomeTooltipCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tip")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tooltipBackground)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
        )
        .frame(maxWidth: 220)
    }

    private var tooltipBackground: Color {
        #if os(macOS)
            Color(nsColor: NSColor.windowBackgroundColor)
        #else
            Color(uiColor: .systemBackground)
        #endif
    }
}

// MARK: - Find in Page Bar

struct FindInPageBar: View {
    @Binding var findText: String
    @Binding var currentIndex: Int
    let totalMatches: Int
    var isFocused: FocusState<Bool>.Binding
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Find in page", text: $findText)
                    .textFieldStyle(.plain)
                    .focused(isFocused)
                    .accessibilityIdentifier("find-in-page-field")
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif

                if !findText.isEmpty {
                    Text("\(totalMatches > 0 ? currentIndex + 1 : 0)/\(totalMatches)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray).opacity(0.2))
            .clipShape(.rect(cornerRadius: 8))

            if !findText.isEmpty {
                Button {
                    if totalMatches > 0 {
                        currentIndex = (currentIndex - 1 + totalMatches) % totalMatches
                    }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(totalMatches == 0)
                .accessibilityIdentifier("find-previous-button")

                Button {
                    if totalMatches > 0 {
                        currentIndex = (currentIndex + 1) % totalMatches
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(totalMatches == 0)
                .accessibilityIdentifier("find-next-button")
            }

            Button("Done", action: onDismiss)
                .fontWeight(.medium)
                .accessibilityIdentifier("find-done-button")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .onAppear {
            isFocused.wrappedValue = true
        }
    }
}
