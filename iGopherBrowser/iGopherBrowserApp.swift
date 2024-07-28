//
//  iGopherBrowserApp.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI
import TelemetryClient

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
        let configuration = TelemetryManagerConfiguration(
            appID: "400187ED-ADA9-4AB4-91F8-8825AD8FC67C")
        TelemetryManager.initialize(with: configuration)

        TelemetryManager.send("applicationDidFinishLaunching")
    }
}
