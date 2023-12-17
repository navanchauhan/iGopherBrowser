//
//  BrowserView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//

import SwiftUI
import swiftGopherClient
import GopherHelpers

struct BrowserView: View {
    
    @State var url: String = ""
    @State private var gopherItems: [gopherItem] = []
    
    @Binding public var hosts: [GopherNode]
    @Binding var selectedNode: GopherNode?
    
    @State private var backwardStack: [GopherNode] = []
    @State private var forwardStack: [GopherNode] = []
    
    @State private var searchText: String = ""
    @State private var showSearchInput = false
    @State var selectedSearchItem: Int?
    
    let client = GopherClient()
    
    var body: some View {
        NavigationStack {
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
                                    Text(Image(systemName: "doc.plaintext"))
                                    Text(item.message)
                                    Spacer()
                                }
                            }
                        } else if [.doc, .image, .gif, .movie, .sound, .bitmap].contains(item.parsedItemType) {
                            NavigationLink(destination: FileView(item: item)) {
                                HStack {
                                    Text(Image(systemName: itemToImageType(item)))
                                    Text(item.message)
                                    Spacer()
                                }
                            }
                        } else {
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
                        
                        Text("Weird bug. Please Dismiss -> Press Go -> Try Again")
                    }
                }
                #if os(iOS)
                VStack {
                    HStack(spacing: 10) {
                        HStack {
                            Spacer()

                            
                            
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
                        
                        Button("Go", action: {
                            performGopherRequest(clearForward: false)
                        })
                        .keyboardShortcut(.defaultAction)
                        .onSubmit {
                            performGopherRequest()
                        }
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Button {
                            performGopherRequest(host:"gopher.navan.dev",port: 70,selector: "/")
                        } label: {
                            Label("Home", systemImage: "house")
                                .labelStyle(.iconOnly)
                        }
                        Spacer()
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
                        Spacer()
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
                        Spacer()
                    }
                }
                #else
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
#if !os(OSX)
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
                #endif
            }
    }
        .onChange(of: selectedNode) {
            if let node = selectedNode {
                performGopherRequest(host: node.host, port: node.port, selector: node.selector)
            }
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

}
