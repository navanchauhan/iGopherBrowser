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
    @AppStorage("crtPhosphorColor") private var crtPhosphorColor: String = CRTPhosphorColor.green.rawValue
    @AppStorage("hasFinishedFirstRunTips") private var hasFinishedFirstRunTips: Bool = false
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion: String = ""

    @State private var showWhatsNew = false
    @State private var pendingWhatsNewFeatures: [WhatsNewFeature] = []

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
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(
                features: pendingWhatsNewFeatures,
                dismissTitle: "Continue",
                onPrimaryAction: {
                    activateCRTPreview()
                },
                onDismiss: {
                    lastSeenWhatsNewVersion = WhatsNewConfig.currentVersion
                    showWhatsNew = false
                }
            )
            #if os(macOS)
                .frame(width: 420, height: 520)
            #endif
        }
        .onAppear {
            evaluateWhatsNewPresentation()
        }
        .onChange(of: hasFinishedFirstRunTips) { _, _ in
            evaluateWhatsNewPresentation()
        }
    }

    private func evaluateWhatsNewPresentation() {
        guard hasFinishedFirstRunTips else {
            showWhatsNew = false
            return
        }

        if lastSeenWhatsNewVersion != WhatsNewConfig.currentVersion {
            pendingWhatsNewFeatures = [
                WhatsNewFeature(
                    id: "crt-mode",
                    title: "CRT Display Mode",
                    message:
                        "Immerse yourself in phosphor glow, scanlines, and subtle vignette effects for every Gopherhole. You can change the display style anytime in Settings.",
                    iconSystemName: "display"
                )
            ]
            showWhatsNew = true
        }
    }

    private func activateCRTPreview() {
        crtMode = true
        crtPhosphorColor = CRTPhosphorColor.amber.rawValue
    }

}

//#Preview {
//  ContentView()
//  //.modelContainer(for: Item.self, inMemory: true)
//}
