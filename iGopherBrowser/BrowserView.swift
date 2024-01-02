//
//  BrowserView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//

import GopherHelpers
import SwiftUI
import TelemetryClient
import swiftGopherClient

func openURL(url: URL) {
  #if os(OSX)
    NSWorkspace.shared.open(url)
  #else
    UIApplication.shared.open(url)
  #endif
}

struct BrowserView: View {
  @AppStorage("homeURL") var homeURL: URL = URL(string: "gopher://gopher.navan.dev:70/")!
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

  let client = GopherClient()

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if gopherItems.count >= 1 {
          List {
            ForEach(Array(gopherItems.enumerated()), id: \.offset) { idx, item in
              if item.parsedItemType == .info {
                Text(item.message)
                  .font(.system(size: 12, design: .monospaced))
                  .frame(height: 20)
                  .listRowSeparator(.hidden)
                  .padding(.vertical, -8)
              } else if item.parsedItemType == .directory {
                Button(action: {
                  performGopherRequest(host: item.host, port: item.port, selector: item.selector)
                }) {
                  HStack {
                    Text(Image(systemName: "folder"))
                    Text(item.message)
                    Spacer()
                  }
                }.buttonStyle(PlainButtonStyle())

              } else if item.parsedItemType == .search {
                Button(action: {
                  self.selectedSearchItem = idx
                  self.showSearchInput = true
                }) {
                  HStack {
                    Text(Image(systemName: "magnifyingglass"))
                    Text(item.message)
                    Spacer()
                  }
                }.buttonStyle(PlainButtonStyle())

              } else if item.parsedItemType == .text {
                NavigationLink(destination: FileView(item: item)) {
                  HStack {
                    Text(Image(systemName: "doc.plaintext"))
                    Text(item.message)
                    Spacer()
                  }
                }
              } else if item.selector.hasPrefix("URL:") {
                if let url = URL(string: item.selector.replacingOccurrences(of: "URL:", with: "")) {
                  //UIApplication.shared.canOpenURL(url) {
                  Button(action: {
                    openURL(url: url)
                  }) {
                    HStack {
                      Image(systemName: "link")
                      Text(item.message)
                      Spacer()
                    }
                  }.buttonStyle(PlainButtonStyle())
                }
              } else if [.doc, .image, .gif, .movie, .sound, .bitmap].contains(item.parsedItemType)
              {
                NavigationLink(destination: FileView(item: item)) {
                  HStack {
                    Text(Image(systemName: itemToImageType(item)))
                    Text(item.message)
                    Spacer()
                  }
                }
              } else {
                Button(action: {
                  TelemetryManager.send(
                    "applicationBrowsedUnknown",
                    with: ["gopherURL": "\(item.host):\(item.port)\(item.selector)"])
                  performGopherRequest(host: item.host, port: item.port, selector: item.selector)
                }) {
                  HStack {
                    Text(Image(systemName: "questionmark.app.dashed"))
                    Text(item.message)
                    Spacer()
                  }
                }.buttonStyle(PlainButtonStyle())

              }
            }
          }
          .background(Color.white)
          .cornerRadius(10)
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
                    "applicationSearchError", with: ["gopherURL": "\(self.url)"])
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
                  TelemetryManager.send("applicationClickedGo", with: ["gopherURL": "\(self.url)"])
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
                TelemetryManager.send("applicationClickedHome", with: ["gopherURL": "\(self.url)"])
                performGopherRequest(
                  host: homeURL.host ?? "gopher.navan.dev", port: homeURL.port ?? 70,
                  selector: homeURL.path)
              } label: {
                Label("Home", systemImage: "house")
                  .labelStyle(.iconOnly)
              }
              Spacer()
              Button {
                if let curNode = backwardStack.popLast() {
                  forwardStack.append(curNode)
                  if let prevNode = backwardStack.popLast() {
                    TelemetryManager.send(
                      "applicationClickedBack",
                      with: ["gopherURL": "\(prevNode.host):\(prevNode.port)\(prevNode.selector)"])
                    performGopherRequest(
                      host: prevNode.host, port: prevNode.port, selector: prevNode.selector,
                      clearForward: false)
                  }
                }
              } label: {
                Label("Back", systemImage: "chevron.left")
                  .labelStyle(.iconOnly)
              }
              .disabled(backwardStack.count < 2)
              Spacer()
              Button {
                if let nextNode = forwardStack.popLast() {
                  TelemetryManager.send(
                    "applicationClickedForward",
                    with: ["gopherURL": "\(nextNode.host):\(nextNode.port)\(nextNode.selector)"])
                  performGopherRequest(
                    host: nextNode.host, port: nextNode.port, selector: nextNode.selector,
                    clearForward: false)
                }
              } label: {
                Label("Forward", systemImage: "chevron.right")
                  .labelStyle(.iconOnly)
              }
              .disabled(forwardStack.isEmpty)
              Spacer()
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
                TelemetryManager.send("applicationClickedHome", with: ["gopherURL": "\(self.url)"])
                performGopherRequest(
                  host: homeURL.host ?? "gopher.navan.dev", port: homeURL.port ?? 70,
                  selector: homeURL.path)
              } label: {
                Label("Home", systemImage: "house")
                  .labelStyle(.iconOnly)
              }

              Button {
                if let curNode = backwardStack.popLast() {
                  forwardStack.append(curNode)
                  if let prevNode = backwardStack.popLast() {
                    TelemetryManager.send(
                      "applicationClickedBack",
                      with: ["gopherURL": "\(prevNode.host):\(prevNode.port)\(prevNode.selector)"])
                    performGopherRequest(
                      host: prevNode.host, port: prevNode.port, selector: prevNode.selector,
                      clearForward: false)
                  }
                }
              } label: {
                Label("Back", systemImage: "chevron.left")
                  .labelStyle(.iconOnly)
              }
              .disabled(backwardStack.count < 2)

              Button {
                if let nextNode = forwardStack.popLast() {
                  TelemetryManager.send(
                    "applicationClickedForward",
                    with: ["gopherURL": "\(nextNode.host):\(nextNode.port)\(nextNode.selector)"])
                  performGopherRequest(
                    host: nextNode.host, port: nextNode.port, selector: nextNode.selector,
                    clearForward: false)
                }
              } label: {
                Label("Forward", systemImage: "chevron.right")
                  .labelStyle(.iconOnly)
              }
              .disabled(forwardStack.isEmpty)

              TextField("Enter a URL", text: $url)
                #if !os(OSX)
                  .keyboardType(.URL)
                  .autocapitalization(.none)
                #endif
                .padding(10)
              Spacer()
            }
            //.background(Color.white)
            .cornerRadius(30)

            Button(
              "Go",
              action: {
                TelemetryManager.send("applicationClickedGo", with: ["gopherURL": "\(self.url)"])
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
    .sheet(
      isPresented: $showPreferences,
      onDismiss: {
        print("badm", homeURL, homeURLString)
        if let url = URL(string: homeURLString) {
          self.homeURL = url
        }
      }
    ) {
      #if os(iOS)
        SettingsView(homeURL: $homeURL, homeURLString: $homeURLString)
      #else
        SettingsView()
      #endif
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

    client.sendRequest(to: res.host, port: res.port, message: "\(res.selector)\r\n") { result in
      switch result {
      case .success(let resp):
        //print(resp)
        var newNode = GopherNode(
          host: res.host, port: res.port, selector: selector, item: nil,
          children: convertToHostNodes(resp))
        backwardStack.append(newNode)
        if clearForward {
          forwardStack.removeAll()
        }
        print(newNode.selector)
        if let index = self.hosts.firstIndex(where: { $0.host == res.host && $0.port == res.port })
        {
          // TODO: Handle case where first link visited is a subdirectory, should the sidebar auto fetch the rest?
          print("parent already exists")
          //hosts[index] = newNode
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
          print("created new")
        }
        self.gopherItems = resp

      case .failure(let error):
        TelemetryManager.send(
          "applicationRequestError", with: ["gopherURL": "\(self.url)", "errorMessage": "\(error)"])
        print("Error \(error)")
        var item = gopherItem(rawLine: "Error \(error)")
        item.message = "Error \(error)"
        self.gopherItems = [item]
      }
    }
  }

  private func convertToHostNodes(_ responseItems: [gopherItem]) -> [GopherNode] {
    var returnItems: [GopherNode] = []
    responseItems.forEach { item in
      if item.parsedItemType != .info {
        returnItems.append(
          GopherNode(
            host: item.host, port: item.port, selector: item.selector, message: item.message,
            item: item, children: nil))
        //print("found: \(item.message)")
      }
    }
    return returnItems
  }

}
