//
//  BrowserView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//

import GopherHelpers
import SwiftData
import SwiftGopherClient
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

    @State var url: String = ""
    @State private var gopherItems: [gopherItem] = []

    @Binding public var hosts: [GopherNode]
    @Binding var selectedNode: GopherNode?

    @State private var backwardStack: [GopherNode] = []
    @State private var forwardStack: [GopherNode] = []

    @State private var searchText: String = ""
    @State private var showSearchInput = false
    @State var selectedSearchItem: Int?
    // Supports presenting SearchInputView when deep-linking directly to a search selector
    @State private var directSearchContext: (host: String, port: Int, selector: String)? = nil

    @State private var showPreferences = false
    @State private var showBookmarks = false
    @State private var showAddBookmark = false
    @State private var currentHost: String = ""
    @State private var currentPort: Int = 70
    @State private var currentSelector: String = ""

    @Namespace var topID
    @State private var scrollToTop: Bool = false

    @State var currentTask: Task<Void, Never>?
    @State private var showHomeTooltip: Bool = false

    @FocusState private var isURLFocused: Bool

    // Find in page
    @State private var showFindInPage = false
    @State private var findText: String = ""
    @State private var currentFindIndex: Int = 0
    @FocusState private var isFindFocused: Bool

    private let homeTooltipMessage = "Tap Home to visit your first Gopherhole."

    private var findMatches: [Int] {
        guard !findText.isEmpty else { return [] }
        return gopherItems.enumerated().compactMap { idx, item in
            item.message.localizedCaseInsensitiveContains(findText) ? idx : nil
        }
    }
    
    let client = GopherClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if gopherItems.count >= 1 {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(gopherItems.enumerated()), id: \.offset) { idx, item in
                                Group {
                                if item.parsedItemType == .info {
                                    Text(item.message)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(effectiveTextColor)
                                        .shadow(color: crtMode ? effectiveTextColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                                        .frame(height: 20)
                                        .listRowSeparator(.hidden)
                                        .padding(.vertical, -8)
                                        .id(idx)
                                } else if item.parsedItemType == .directory {
                                    Button(action: {
                                        performGopherRequest(
                                            host: item.host, port: item.port,
                                            selector: item.selector)
                                        #if canImport(UIKit)
                                            hideKeyboard()
                                        #endif
                                    }) {
                                        HStack {
                                            Text(Image(systemName: "folder"))
                                            Text(item.message)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .foregroundStyle(effectiveLinkColor)
                                        .shadow(color: crtMode ? effectiveLinkColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                                    }.buttonStyle(PlainButtonStyle())
                                        .id(idx)
                                } else if item.parsedItemType == .search {
                                    Button(action: {
                                        #if canImport(UIKit)
                                            hideKeyboard()
                                        #endif
                                        // Always present the search sheet, even when re-tapping the same item
                                        self.selectedSearchItem = idx
                                        self.showSearchInput = true
                                    }) {
                                        HStack {
                                            Text(Image(systemName: "magnifyingglass"))
                                            Text(item.message)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .foregroundStyle(effectiveLinkColor)
                                        .shadow(color: crtMode ? effectiveLinkColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                                    }.buttonStyle(PlainButtonStyle())
                                        .id(idx)
                                } else if item.parsedItemType == .text {
                                    NavigationLink(destination: FileView(item: item)) {
                                        HStack {
                                            Text(Image(systemName: "doc.plaintext"))
                                            Text(item.message)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .foregroundStyle(effectiveLinkColor)
                                        .shadow(color: crtMode ? effectiveLinkColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                                    }
                                    .id(idx)
                                } else if item.selector.hasPrefix("URL:") {
                                    if let url = URL(
                                        string: item.selector.replacingOccurrences(
                                            of: "URL:", with: ""))
                                    {
                                        //UIApplication.shared.canOpenURL(url) {
                                        Button(action: {
                                            openURL(url: url)
                                        }) {
                                            HStack {
                                                Image(systemName: "link")
                                                Text(item.message)
                                                Spacer()
                                            }
                                            .contentShape(Rectangle())
                                            .foregroundStyle(effectiveLinkColor)
                                            .shadow(color: crtMode ? effectiveLinkColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                                        }.buttonStyle(PlainButtonStyle())
                                            .id(idx)
                                    }
                                } else if [.doc, .image, .gif, .movie, .sound, .bitmap, .binary].contains(
                                    item.parsedItemType)
                                {
                                    NavigationLink(destination: FileView(item: item)) {
                                        HStack {
                                            Text(Image(systemName: itemToImageType(item)))
                                            Text(item.message)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .foregroundStyle(effectiveLinkColor)
                                        .shadow(color: crtMode ? effectiveLinkColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                                    }
                                    .id(idx)
                                } else {
                                    Button(action: {
                                        TelemetryDeck.signal(
                                            "applicationBrowsedUnknown",
                                            parameters: [
                                                "gopherURL":
                                                    "\(item.host):\(item.port)\(item.selector)"
                                            ])
                                        performGopherRequest(
                                            host: item.host, port: item.port,
                                            selector: item.selector)
                                    }) {
                                        HStack {
                                            Text(Image(systemName: "questionmark.app.dashed"))
                                            Text(item.message)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .foregroundStyle(effectiveLinkColor)
                                        .shadow(color: crtMode ? effectiveLinkColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                                    }.buttonStyle(PlainButtonStyle())
                                        .id(idx)
                                }
                                }
                                .listRowBackground(rowBackgroundColor(for: idx))
                            }
                        }
                        .scrollContentBackground(crtMode ? .hidden : .automatic)
                        .background(crtMode ? Color.clear : Color.clear)
                        .cornerRadius(10)
                        .onChange(of: scrollToTop) { _, _ in
                            // TODO: Cleanup
                            proxy.scrollTo(0, anchor: .top)
                        }
                        .onChange(of: selectedSearchItem) { _, newValue in
                            if newValue != nil {
                                self.showSearchInput = true
                            }
                        }
                        .onChange(of: currentFindIndex) { _, newIndex in
                            if !findMatches.isEmpty && newIndex < findMatches.count {
                                withAnimation {
                                    proxy.scrollTo(findMatches[newIndex], anchor: .center)
                                }
                            }
                        }
                        .onChange(of: findText) { _, _ in
                            currentFindIndex = 0
                            if !findMatches.isEmpty {
                                withAnimation {
                                    proxy.scrollTo(findMatches[0], anchor: .center)
                                }
                            }
                        }
                        .safeAreaInset(edge: .top) {
                            if showFindInPage {
                                FindInPageBar(
                                    findText: $findText,
                                    currentIndex: $currentFindIndex,
                                    totalMatches: findMatches.count,
                                    isFocused: $isFindFocused,
                                    onDismiss: {
                                        showFindInPage = false
                                        findText = ""
                                    }
                                )
                            }
                        }
                    }
                    .sheet(isPresented: $showSearchInput, onDismiss: {
                        // Reset contexts so tapping the same item or deep-link works again
                        self.selectedSearchItem = nil
                        self.directSearchContext = nil
                    }) {
                        if let index = selectedSearchItem, gopherItems.indices.contains(index) {
                            let searchItem = gopherItems[index]
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
                        } else if let ctx = directSearchContext {
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
                                        "applicationSearchError", parameters: ["gopherURL": "\(self.url)"]
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
                        url: $url,
                        homeURL: homeURL,
                        shareThroughProxy: shareThroughProxy,
                        backwardStack: backwardStack,
                        forwardStack: forwardStack,
                        currentHost: currentHost,
                        showAddBookmark: $showAddBookmark,
                        showBookmarks: $showBookmarks,
                        showPreferences: $showPreferences,
                        showFindInPage: $showFindInPage,
                        hasContent: !gopherItems.isEmpty,
                        onGo: {
                            TelemetryDeck.signal(
                                "applicationClickedGo", parameters: ["gopherURL": "\(self.url)"])
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
                        url: $url,
                        isURLFocused: $isURLFocused,
                        homeURL: homeURL,
                        shareThroughProxy: shareThroughProxy,
                        backwardStack: backwardStack,
                        forwardStack: forwardStack,
                        currentHost: currentHost,
                        showAddBookmark: $showAddBookmark,
                        showBookmarks: $showBookmarks,
                        showPreferences: $showPreferences,
                        onGo: {
                            TelemetryDeck.signal(
                                "applicationClickedGo", parameters: ["gopherURL": "\(self.url)"])
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
        .onOpenURL { gopherURL in
            self.url = gopherURL.absoluteString
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
        .accentColor(accentColour)
        
        .onAppear {
            if !hasFinishedFirstRunTips && !showHomeTooltip {
                withAnimation(.spring()) {
                    showHomeTooltip = true
                }
            }
            #if os(OSX)
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Command+F for Find in Page
                if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.option) && event.charactersIgnoringModifiers == "f" {
                    if !gopherItems.isEmpty {
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
                        findText = ""
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
                if !gopherItems.isEmpty {
                    showFindInPage = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
        }
    }
    
    private func goBack() {
        if let curNode = backwardStack.popLast() {
            forwardStack.append(curNode)
            if let prevNode = backwardStack.popLast() {
                TelemetryDeck.signal(
                    "applicationClickedBack",
                    parameters: [
                        "gopherURL":
                            "\(prevNode.host):\(prevNode.port)\(prevNode.selector)"
                    ])
                performGopherRequest(
                    host: prevNode.host, port: prevNode.port,
                    selector: prevNode.selector,
                    clearForward: false)
            }
        }
    }
    
    private func goForward() {
        if let curNode = backwardStack.popLast() {
            forwardStack.append(curNode)
            if let prevNode = backwardStack.popLast() {
                TelemetryDeck.signal(
                    "applicationClickedBack",
                    parameters: [
                        "gopherURL":
                            "\(prevNode.host):\(prevNode.port)\(prevNode.selector)"
                    ])
                performGopherRequest(
                    host: prevNode.host, port: prevNode.port,
                    selector: prevNode.selector,
                    clearForward: false)
            }
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
            "applicationClickedHome", parameters: ["gopherURL": "\(self.url)"])
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
        // TODO: Remove getHostandPort call here, and call it before calling performGopherRequest
        print("recieved ", host, port, selector)
        var res = getHostAndPort(from: self.url)

        if host != "" {
            res.host = host
            if selector != "" {
                res.selector = selector
            } else {
                res.selector = ""
            }
        }

        if port != -1 {
            res.port = port
        }

        // Normalize selector for search handling (decode percent-encoding for cases like %09)
        var finalSelector = res.selector
        if let decoded = finalSelector.removingPercentEncoding {
            finalSelector = decoded
        }

        // Handle deep-link to search selector: present SearchInputView if no query
        if finalSelector.hasPrefix("/search") {
            // If a query is present (tab-delimited), proceed with the request directly
            if finalSelector.contains("\t") {
                res.selector = finalSelector
            } else {
                // No query provided — present the search input sheet with proper context
                self.searchText = ""
                self.selectedSearchItem = nil
                self.directSearchContext = (host: res.host, port: res.port, selector: "/search")
                self.showSearchInput = true
                return
            }
        }

        // Update the visible URL string
        self.url = "\(res.host):\(res.port)\(res.selector)"

        // Track current location for bookmarking
        self.currentHost = res.host
        self.currentPort = res.port
        self.currentSelector = res.selector

        currentTask?.cancel()

        let myHost = res.host
        let myPort = res.port
        let mySelector = res.selector

        currentTask = Task {
            do {
                try Task.checkCancellation()
                let resp = try await client.sendRequest(
                    to: myHost, port: myPort, message: "\(mySelector)\r\n")

                var newNode = GopherNode(
                    host: myHost, port: myPort, selector: mySelector, item: nil,
                    children: convertToHostNodes(resp))

                backwardStack.append(newNode)
                if clearForward {
                    forwardStack.removeAll()
                }

                if let index = self.hosts.firstIndex(where: {
                    $0.host == myHost && $0.port == myPort
                }) {
                    // TODO: Handle case where first link visited is a subdirectory, should the sidebar auto fetch the rest?
                    hosts[index].children = hosts[index].children?.map { child in
                        if child.selector == newNode.selector {
                            newNode.message = child.message
                            return newNode
                        } else {
                            return child
                        }
                    }
                } else {
                    newNode.selector = "/"
                    hosts.append(newNode)
                }
                //TODO: Fix this stupid bodge
                if self.url != "\(myHost):\(myPort)\(mySelector)" {
                    print("Different URL being processed right now... Cancelling")
                } else {
                    self.gopherItems = resp
                    scrollToTop.toggle()

                    // Save to history
                    let historyItem = HistoryItem(
                        title: "\(myHost)\(mySelector)",
                        host: myHost,
                        port: myPort,
                        selector: mySelector
                    )
                    modelContext.insert(historyItem)
                }

            } catch is CancellationError {
                print("Request was cancelled")
            } catch {
                TelemetryDeck.signal(
                    "applicationRequestError",
                    parameters: ["gopherURL": "\(self.url)", "errorMessage": "\(error)"])
                print("Error \(error)")
                var item = gopherItem(rawLine: "Error \(error)")
                item.message = "Error \(error)"
                if self.url != "\(myHost):\(myPort)\(mySelector)" {
                    print("Different URL being processed right now... Cancelling")
                } else {
                    self.gopherItems = [item]
                }
            }
        }
    }
    
    private func rowBackgroundColor(for idx: Int) -> Color? {
        // Find highlight takes priority
        if findMatches.contains(idx) {
            if crtMode {
                if findMatches.firstIndex(of: idx) == currentFindIndex {
                    return crtPhosphorColor.opacity(0.3)
                }
                return crtPhosphorColor.opacity(0.15)
            } else {
                if findMatches.firstIndex(of: idx) == currentFindIndex {
                    return Color.yellow.opacity(0.5)
                }
                return Color.yellow.opacity(0.2)
            }
        }

        return crtMode ? CRTTheme.screenBackground : nil
    }

    private func convertToHostNodes(_ responseItems: [gopherItem]) -> [GopherNode] {
        var returnItems: [GopherNode] = []
        responseItems.forEach { item in
            if item.parsedItemType != .info {
                returnItems.append(
                    GopherNode(
                        host: item.host, port: item.port, selector: item.selector,
                        message: item.message,
                        item: item, children: nil))
                //print("found: \(item.message)")
            }
        }
        return returnItems
    }

}

#if os(iOS)
struct iOSToolbarView: View {
    @Binding var url: String
    let homeURL: URL
    let shareThroughProxy: Bool
    let backwardStack: [GopherNode]
    let forwardStack: [GopherNode]
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
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Bottom toolbar - cleaner design
            HStack(spacing: 0) {
                // Navigation group
                HStack(spacing: 4) {
                    navButton(icon: "chevron.left", action: onBack)
                        .disabled(backwardStack.count < 2)

                    navButton(icon: "chevron.right", action: onForward)
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
                        navButton(icon: "house", action: onHome)
                    }

                    Button(action: { showAddBookmark = true }) {
                        Image(systemName: currentHost.isEmpty ? "bookmark" : "bookmark.fill")
                            .font(.system(size: 18))
                            .frame(width: 44, height: 36)
                    }
                    .disabled(currentHost.isEmpty)
                }
                .modifier(ToolbarGroupStyle())

                Spacer()

                // Right actions group
                HStack(spacing: 4) {
                    navButton(icon: "clock.arrow.circlepath", action: { showBookmarks = true })

                    Menu {
                        Button(action: { showFindInPage = true }) {
                            Label("Find in Page", systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(!hasContent)

                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(action: { showPreferences = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .frame(width: 44, height: 36)
                    }
                }
                .modifier(ToolbarGroupStyle())
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 44, height: 36)
        }
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
                .foregroundColor(.white)
                .cornerRadius(8)
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
                .cornerRadius(10)
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
    let backwardStack: [GopherNode]
    let forwardStack: [GopherNode]
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
                }

                Button(action: { showPreferences = true }) {
                    Label("Settings", systemImage: "gear")
                        .labelStyle(.iconOnly)
                }

                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(backwardStack.count < 2)

                Button(action: onForward) {
                    Label("Forward", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(forwardStack.isEmpty)
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
                        }

                        Button(action: onBack) {
                            Label("Back", systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                        }
                        .glassEffect(.regular.interactive())
                        .keyboardShortcut("[", modifiers: [.command])
                        .disabled(backwardStack.count < 2)

                        Button(action: onForward) {
                            Label("Forward", systemImage: "chevron.right")
                                .labelStyle(.iconOnly)
                        }
                        .glassEffect(.regular.interactive())
                        .keyboardShortcut("]", modifiers: [.command])
                        .disabled(forwardStack.isEmpty)
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
                    }

                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                    }
                    .keyboardShortcut("[", modifiers: [.command])
                    .disabled(backwardStack.count < 2)

                    Button(action: onForward) {
                        Label("Forward", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                    }
                    .keyboardShortcut("]", modifiers: [.command])
                    .disabled(forwardStack.isEmpty)
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
        #else
            if #available(macOS 26.0, *) {
                TextField("Enter a URL", text: $url)
                    .focused(isURLFocused)
                    .padding(10)
                    .glassEffect(in: .rect(cornerRadius: 8))
            } else {
                TextField("Enter a URL", text: $url)
                    .focused(isURLFocused)
                    .padding(10)
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

                Button(action: { showBookmarks = true }) {
                    Label("Bookmarks", systemImage: "book")
                        .labelStyle(.iconOnly)
                }

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

                        Button(action: { showBookmarks = true }) {
                            Label("Bookmarks", systemImage: "book")
                                .labelStyle(.iconOnly)
                        }
                        .glassEffect(.regular.interactive())

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

                    Button(action: { showBookmarks = true }) {
                        Label("Bookmarks", systemImage: "book")
                            .labelStyle(.iconOnly)
                    }

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
            .cornerRadius(8)

            if !findText.isEmpty {
                Button {
                    if totalMatches > 0 {
                        currentIndex = (currentIndex - 1 + totalMatches) % totalMatches
                    }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(totalMatches == 0)

                Button {
                    if totalMatches > 0 {
                        currentIndex = (currentIndex + 1) % totalMatches
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(totalMatches == 0)
            }

            Button("Done", action: onDismiss)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .onAppear {
            isFocused.wrappedValue = true
        }
    }
}
