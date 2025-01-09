//
//  BrowserView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//

import GopherHelpers
import SwiftGopherClient
import SwiftUI
import TelemetryClient

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
    @AppStorage("homeURL") var homeURL: URL = URL(string: "gopher://gopher.navan.dev:70/")!
    @AppStorage("accentColour", store: .standard) var accentColour: Color = Color(.blue)
    @AppStorage("linkColour", store: .standard) var linkColour: Color = Color(.white)
    @AppStorage("shareThroughProxy", store: .standard) var shareThroughProxy: Bool = true

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

    @State private var showPreferences = false
    @State private var showBookmarks = false

    @Namespace var topID
    @State private var scrollToTop: Bool = false

    @State var currentTask: Task<Void, Never>?
    
    @FocusState private var isURLFocused: Bool
    
    let client = GopherClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if gopherItems.count >= 1 {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(gopherItems.enumerated()), id: \.offset) { idx, item in
                                if item.parsedItemType == .info {
                                    Text(item.message)
                                        .font(.system(size: 12, design: .monospaced))
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
                                        }.foregroundStyle(linkColour)
                                    }.buttonStyle(PlainButtonStyle())
                                        .id(idx)
                                } else if item.parsedItemType == .search {
                                    Button(action: {
                                        #if canImport(UIKit)
                                            hideKeyboard()
                                        #endif
                                        self.selectedSearchItem = idx
                                    }) {
                                        HStack {
                                            Text(Image(systemName: "magnifyingglass"))
                                            Text(item.message)
                                            Spacer()
                                        }.foregroundStyle(linkColour)
                                    }.buttonStyle(PlainButtonStyle())
                                        .id(idx)
                                } else if item.parsedItemType == .text {
                                    NavigationLink(destination: FileView(item: item)) {
                                        HStack {
                                            Text(Image(systemName: "doc.plaintext"))
                                            Text(item.message)
                                            Spacer()
                                        }.foregroundStyle(linkColour)
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
                                            }.foregroundStyle(linkColour)
                                        }.buttonStyle(PlainButtonStyle())
                                            .id(idx)
                                    }
                                } else if [.doc, .image, .gif, .movie, .sound, .bitmap].contains(
                                    item.parsedItemType)
                                {
                                    NavigationLink(destination: FileView(item: item)) {
                                        HStack {
                                            Text(Image(systemName: itemToImageType(item)))
                                            Text(item.message)
                                            Spacer()
                                        }.foregroundStyle(linkColour)
                                            .id(idx)
                                    }
                                } else {
                                    Button(action: {
                                        TelemetryManager.send(
                                            "applicationBrowsedUnknown",
                                            with: [
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
                                        }.foregroundStyle(linkColour)
                                    }.buttonStyle(PlainButtonStyle())
                                        .id(idx)
                                }

                            }
                        }
                        //.background(Color.white)
                        .cornerRadius(10)
                        .onChange(of: scrollToTop) {
                            // TODO: Cleanup
                            proxy.scrollTo(0, anchor: .top)
                        }
                        .onChange(of: selectedSearchItem) {
                            if let selectedSearchItem = selectedSearchItem {
                                self.showSearchInput = true
                            }
                        }
                    }
                    .sheet(isPresented: $showSearchInput) {
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
                        } else {

                            VStack {
                                Text("Weird bug. Please Dismiss -> Press Go -> Try Again")
                                Button("Dismiss") {
                                    self.showSearchInput = false
                                }.onAppear {
                                    TelemetryManager.send(
                                        "applicationSearchError", with: ["gopherURL": "\(self.url)"]
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
                    VStack {
                        HStack(spacing: 10) {
                            HStack {
                                Spacer()

                                TextField("Enter a URL", text: $url)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                Spacer()
                            }
                            //.background(Color.white)
                            .cornerRadius(30)

                            Button(
                                "Go",
                                action: {
                                    TelemetryManager.send(
                                        "applicationClickedGo", with: ["gopherURL": "\(self.url)"])
                                    performGopherRequest(clearForward: false)

                                }
                            )
                            .keyboardShortcut(.defaultAction)
                            .onSubmit {
                                performGopherRequest()
                            }
                            Spacer()
                        }
                        .padding(.bottom, 10)
                        .padding(.top, 5)
                        HStack {
                            Spacer()
                            Button {
                                print(homeURL, "home")
                                TelemetryManager.send(
                                    "applicationClickedHome", with: ["gopherURL": "\(self.url)"])
                                performGopherRequest(
                                    host: homeURL.host ?? "gopher.navan.dev",
                                    port: homeURL.port ?? 70,
                                    selector: homeURL.path)
                            } label: {
                                Label("Home", systemImage: "house")
                                    .labelStyle(.iconOnly)
                            }
                            .keyboardShortcut("r", modifiers: [.command])
                            Spacer()
                            Button {
                                goBack();

                            } label: {
                                Label("Back", systemImage: "chevron.left")
                                    .labelStyle(.iconOnly)
                            }
                            .keyboardShortcut("[", modifiers: [.command])
                            .disabled(backwardStack.count < 2)
                            Spacer()
                            Button {
                                goForward()
                            } label: {
                                Label("Forward", systemImage: "chevron.right")
                                    .labelStyle(.iconOnly)
                            }
                            .keyboardShortcut("]", modifiers: [.command])
                            .disabled(forwardStack.isEmpty)
                            Spacer()
                            if shareThroughProxy {
                                ShareLink(item: URL(string: "https://gopher.navan.dev/\(url)")!) {
                                    Label("Share", systemImage: "square.and.arrow.up").labelStyle(
                                        .iconOnly)
                                }
                            } else {
                                ShareLink(item: URL(string: "gopher://\(url)")!) {
                                    Label("Share", systemImage: "square.and.arrow.up").labelStyle(
                                        .iconOnly)
                                }
                            }
                            Spacer()
                            //                Button {
                            //                    showBookmarks = true
                            //                } label: {
                            //                    Label("Bookmarks", systemImage: "book")
                            //                        .labelStyle(.iconOnly)
                            //                }.sheet(isPresented: $showBookmarks) {
                            //                    BookmarksView()
                            //                        .presentationDetents([.height(400), .medium, .large])
                            //                        .presentationDragIndicator(.automatic)
                            //                }
                            //              Spacer()
                            Button {
                                self.showPreferences = true
                            } label: {
                                Label("Settings", systemImage: "gear")
                                    .labelStyle(.iconOnly)
                            }
                            Spacer()
                        }
                    }
                #else
                    HStack(spacing: 10) {
                        HStack {
                            Spacer()
                            Button {
                                TelemetryManager.send(
                                    "applicationClickedHome", with: ["gopherURL": "\(self.url)"])
                                performGopherRequest(
                                    host: homeURL.host ?? "gopher.navan.dev",
                                    port: homeURL.port ?? 70,
                                    selector: homeURL.path)
                            } label: {
                                Label("Home", systemImage: "house")
                                    .labelStyle(.iconOnly)
                            }
                            .keyboardShortcut("r", modifiers: [.command])

                            #if os(visionOS)
                                Button {
                                    self.showPreferences = true
                                } label: {
                                    Label("Settings", systemImage: "gear")
                                        .labelStyle(.iconOnly)
                                }
                            #endif

                            Button {
                                goBack()
                            } label: {
                                Label("Back", systemImage: "chevron.left")
                                    .labelStyle(.iconOnly)
                            }
                            .keyboardShortcut("[", modifiers: [.command])
                            .disabled(backwardStack.count < 2)

                            Button {
                                goForward();
                           } label: {
                                Label("Forward", systemImage: "chevron.right")
                                    .labelStyle(.iconOnly)
                            }
                           .keyboardShortcut("]", modifiers: [.command])
                            .disabled(forwardStack.isEmpty)

                            TextField("Enter a URL", text: $url)
                                #if !os(OSX)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                #endif
                                    .focused($isURLFocused)
                                .padding(10)
                       }
                        //.background(Color.white)
                        .cornerRadius(30)
                        if shareThroughProxy {
                            ShareLink(item: URL(string: "https://gopher.navan.dev/\(url)")!) {
                                Label("Share", systemImage: "square.and.arrow.up").labelStyle(
                                    .iconOnly)
                            }
                        } else {
                            ShareLink(item: URL(string: "gopher://\(url)")!) {
                                Label("Share", systemImage: "square.and.arrow.up").labelStyle(
                                    .iconOnly)
                            }
                        }
                        Button(
                            "Go",
                            action: {
                                TelemetryManager.send(
                                    "applicationClickedGo", with: ["gopherURL": "\(self.url)"])
                                performGopherRequest(clearForward: false)
                            }
                        )
                        .keyboardShortcut(.defaultAction)
                        .onSubmit {
                            performGopherRequest()
                        }
                        Spacer()
                    }
                #endif
            }
        }
        .onChange(of: selectedNode) {
            if let node = selectedNode {
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
        .accentColor(accentColour)
        
        .onAppear {
            #if os(OSX)
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains([.option, .command]) && event.charactersIgnoringModifiers == "f" {
                    isURLFocused = true
                    return nil
                } else if event.keyCode == 53 {
                    isURLFocused = false
                    return nil
                }
                return event
            }
            #endif
        }
    }
    
    private func goBack() {
        if let curNode = backwardStack.popLast() {
            forwardStack.append(curNode)
            if let prevNode = backwardStack.popLast() {
                TelemetryManager.send(
                    "applicationClickedBack",
                    with: [
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
                TelemetryManager.send(
                    "applicationClickedBack",
                    with: [
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

        self.url = "\(res.host):\(res.port)\(res.selector)"

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
                }

            } catch is CancellationError {
                print("Request was cancelled")
            } catch {
                TelemetryManager.send(
                    "applicationRequestError",
                    with: ["gopherURL": "\(self.url)", "errorMessage": "\(error)"])
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
