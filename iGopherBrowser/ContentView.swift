//
//  ContentView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import GopherHelpers
import SwiftGopherClient
import SwiftUI

struct GopherNode: Identifiable, Equatable {
    static func == (lhs: GopherNode, rhs: GopherNode) -> Bool {
        return lhs.host == rhs.host && lhs.port == rhs.port && lhs.selector == rhs.selector
    }

    let id = UUID()
    var host: String
    let port: Int
    var selector: String
    var message: String?
    let item: gopherItem?
    var children: [GopherNode]?
}

struct ContentView: View {

    @State public var hosts: [GopherNode] = []
    @State private var selectedNode: GopherNode?

    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    @AppStorage("crtMode") var crtMode: Bool = false
    @AppStorage("crtScanlines") var crtScanlines: Bool = true
    @AppStorage("crtVignette") var crtVignette: Bool = true

    var body: some View {
        ZStack {
            // Background for CRT mode
            if crtMode {
                CRTTheme.screenBackground
                    .ignoresSafeArea()
            }

            // Main content
            Group {
                #if os(iOS)
                    BrowserView(hosts: $hosts, selectedNode: $selectedNode)
                #else
                    NavigationSplitView(columnVisibility: $columnVisibility) {
                        SidebarView(
                            hosts: hosts,
                            onSelect: { node in
                                selectedNode = node
                            }
                        )
                        .listStyle(.sidebar)
                    } detail: {
                        BrowserView(hosts: $hosts, selectedNode: $selectedNode)
                    }
                #endif
            }

            // CRT overlay effects
            if crtMode {
                if crtScanlines {
                    ScanlineOverlay()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                if crtVignette {
                    CRTVignette()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        }
        .preferredColorScheme(crtMode ? .dark : nil)
    }

}

//#Preview {
//  ContentView()
//  //.modelContainer(for: Item.self, inMemory: true)
//}
