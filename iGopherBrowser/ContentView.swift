//
//  ContentView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI
import SwiftData

import swiftGopherClient

struct GopherNode: Identifiable {
    let id = UUID()
    var host: String
    let port: Int
    var selector: String
    var message: String?
    let item: gopherItem?
    var children: [GopherNode]?
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State var url: String = ""
    @State private var gopherItems: [gopherItem] = []
    @State public var hosts: [GopherNode] = []
    
    @State private var backwardStack: [GopherNode] = []
    @State private var forwardStack: [GopherNode] = []
    
    @State private var searchText: String = ""
    @State private var showSearchInput = false
    @State var selectedSearchItem: Int?
    
    let client = GopherClient()

    var body: some View {
        NavigationSplitView {
#if os(iOS)
#else
            SidebarView(hosts: hosts, onSelect: { node in
                performGopherRequest(host: node.host, port: node.port, selector: node.selector)
                
            })
            .listStyle(.sidebar)
#endif
        } detail: {
            
            ZStack(alignment: .bottom) {
                
                
                
                VStack(spacing: 0) {
                    List {
                        ForEach(Array(gopherItems.enumerated()), id: \.offset) { idx, item in
                            if item.parsedItemType == .info {
                                Text(item.message)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(height: 20)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                            }  else if item.parsedItemType == .directory  {
                                HStack {
                                    Text(Image(systemName: "folder"))
                                    Text(item.message)
                                    Spacer()
                                }.onTapGesture {
                                    performGopherRequest(host: item.host, port: item.port, selector: item.selector)
                                }
                            } else if item.parsedItemType == .search {
                                HStack {
                                    Text(Image(systemName: "magnifyingglass"))
                                    Text(item.message)
                                    Spacer()
                                }.onTapGesture {
                                    self.selectedSearchItem = idx
                                    self.showSearchInput = true
                                }
                            } else if item.parsedItemType == .text {
                                NavigationLink(destination: FileView(item: item)) {
                                    HStack {
                                        Text(Image(systemName: "doc.text"))
                                        Text(item.message)
                                        Spacer()
                                    }
                                }
                            }
                            else {
                                Text(item.message)
                                    .onTapGesture {
                                        performGopherRequest(host: item.host, port: item.port, selector: item.selector)
                                    }
                                
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
                                    performGopherRequest(host: searchItem.host, port: searchItem.port, selector: "\(searchItem.selector)\t\(query)")
                                    showSearchInput = false
                                }
                            )
                        } else {

                            Text("Search is Broken.")
                        }
                    }
                    HStack(spacing: 10) {
                        HStack {
                            Spacer()
                            Button {
                                performGopherRequest(host:"gopher.navan.dev",port: 70,selector: "/")
                            } label: {
                                Label("Home", systemImage: "house")
                                    .labelStyle(.iconOnly)
                            }
                            
                            Button {
                                if let curNode = backwardStack.popLast() {
                                    forwardStack.append(curNode)
                                    if let prevNode = backwardStack.popLast() {
                                        performGopherRequest(host: prevNode.host, port: prevNode.port, selector: prevNode.selector, clearForward: false)
                                    }
                                }
                            } label: {
                                Label("Back", systemImage: "chevron.left")
                                    .labelStyle(.iconOnly)
                            }
                            .disabled(backwardStack.count < 2)
                            
                            Button {
                                if let nextNode = forwardStack.popLast() {
                                    //backwardStack.append(nextNode)
                                    performGopherRequest(host: nextNode.host, port: nextNode.port, selector: nextNode.selector, clearForward: false)
                                }
                            } label: {
                                Label("Forward", systemImage: "chevron.right")
                                    .labelStyle(.iconOnly)
                            }
                            .disabled(forwardStack.isEmpty)
                            
                            
                            TextField("Enter a URL", text: $url)
#if os(iOS)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
#endif
                                .padding(10)
                            Spacer()
                        }
                        //.background(Color.white)
                        .cornerRadius(30)
                        
                        Button("Go", action: {
                            performGopherRequest(clearForward: false)
                        })
                        .keyboardShortcut(.defaultAction)
                        .onSubmit {
                            performGopherRequest()
                        }
                        Spacer()
                    }
                }
            }
        }.toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar, label: {
                    Image(systemName: "sidebar.leading")
                })
            }
        }
    }
    
    private func toggleSidebar() {
        #if os(iOS)
        #else
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        #endif
    }
    
    public func getHostAndPort(from urlString: String, defaultPort: Int = 70, defaultHost: String = "gopher.navan.dev") -> (host: String, port: Int, selector: String) {
        if let urlComponents = URLComponents(string: urlString),
               let host = urlComponents.host {
                let port = urlComponents.port ?? defaultPort
            let selector = urlComponents.path
            print("Mainmain, ", urlComponents, host, port, selector)
                return (host, port, selector)
            } else {
                // Fallback for simpler formats like "localhost:8080"
                let components = urlString.split(separator: ":")
                let host = components.first.map(String.init) ?? defaultHost
                
                var port = (components.count > 1 ? Int(components[1]) : nil) ?? defaultPort
                var selector = "/"
                
                if (components.count > 1) {
                    let portCompString = components[1]
                    let portCompComponents = portCompString.split(separator: "/", maxSplits: 1)
                    if portCompComponents.count > 1 {
                        port = Int(portCompComponents[0]) ?? defaultPort
                        selector = "/" + portCompComponents[1]
                        
                    }
                }
                
                
                print("Else Else",components, host, port, selector)
                return (host, port, selector)
            }
    }
    
    private func performGopherRequest(host: String = "", port: Int = -1, selector: String = "", clearForward: Bool = true) {
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
            DispatchQueue.main.async {
                switch result {
                case .success(let resp):
                    //print(resp)
                    var newNode = GopherNode(host: res.host, port: res.port, selector: selector, item: nil, children: convertToHostNodes(resp))
                    backwardStack.append(newNode)
                    if clearForward {
                        forwardStack.removeAll()
                    }
                    print(newNode.selector)
                        if let index = self.hosts.firstIndex(where: { $0.host == res.host && $0.port == res.port }) {
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
                    print("Error \(error)")
                    var item = gopherItem(rawLine: "Error \(error)")
                    item.message = "Error \(error)"
                    self.gopherItems = [item]
                }
            }
        }
    }
    

}

private func convertToHostNodes(_ responseItems: [gopherItem]) -> [GopherNode] {
    var returnItems: [GopherNode] = []
    responseItems.forEach { item in
        if item.parsedItemType != .info {
            returnItems.append(GopherNode(host: item.host, port: item.port, selector: item.selector, message: item.message, item: item, children: nil))
            //print("found: \(item.message)")
        }
    }
    return returnItems
}

#Preview {
    ContentView()
        //.modelContainer(for: Item.self, inMemory: true)
}
