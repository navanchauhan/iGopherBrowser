//
//  iGopherBrowserApp.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI
import AppIntents
import TelemetryDeck

@main
struct iGopherBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            #if os(macOS)
                SidebarCommands()
            #endif
        }
        #if os(macOS)
            Settings {
                SettingsView()
            }
        #endif
    }

    init() {
        let configuration = TelemetryDeck.Config(
            appID: "400187ED-ADA9-4AB4-91F8-8825AD8FC67C")
        TelemetryDeck.initialize(config: configuration)

        TelemetryDeck.signal("applicationDidFinishLaunching")
    }
}
