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
    
    let client = GopherClient()

    var body: some View {
        NavigationView {
            
            SidebarView(hosts: hosts, onSelect: { node in
                performGopherRequest(host: node.host, port: node.port, selector: node.selector)
                
            })
                .listStyle(SidebarListStyle())
            
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
                    HStack(spacing: 10) {
                        HStack {
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
                            performGopherRequest()
                        })
                        .keyboardShortcut(.defaultAction)
                        .onSubmit {
                            performGopherRequest()
                        }
                        .padding(10)
                    }
                }
            }
        }
    }
    
    public func getHostAndPort(from urlString: String, defaultPort: Int = 70, defaultHost: String = "gopher.navan.dev") -> (host: String, port: Int) {
        if let urlComponents = URLComponents(string: urlString),
               let host = urlComponents.host {
                let port = urlComponents.port ?? defaultPort
                return (host, port)
            } else {
                // Fallback for simpler formats like "localhost:8080"
                let components = urlString.split(separator: ":")
                let host = components.first.map(String.init) ?? defaultHost
                let port = (components.count > 1 ? Int(components[1]) : nil) ?? defaultPort
                return (host, port)
            }
    }
    
    private func performGopherRequest(host: String = "", port: Int = -1, selector: String = "") {
        
        var res = getHostAndPort(from: self.url)
        
        if host != "" {
            res.host = host
        }
        
        if port != -1 {
            res.port = port
        }
        
        self.url = "\(res.host):\(res.port)\(selector)"
        
        client.sendRequest(to: res.host, port: res.port, message: "\(selector)\r\n") { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let resp):
                    print(resp)
                    var newNode = GopherNode(host: res.host, port: res.port, selector: selector, item: nil, children: convertToHostNodes(resp))
                    print(newNode.selector)
                        if let index = self.hosts.firstIndex(where: { $0.host == res.host && $0.port == res.port }) {
                            if newNode.selector == "" || newNode.selector == "/" {
                                print("do something")
                            } else {
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
                            }
                        } else {
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
            print("found: \(item.message)")
        }
    }
    return returnItems
}

#Preview {
    ContentView()
        //.modelContainer(for: Item.self, inMemory: true)
}
