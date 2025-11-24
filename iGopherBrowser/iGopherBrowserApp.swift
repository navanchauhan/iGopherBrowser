//
//  iGopherBrowserApp.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI
import SwiftData
import AppIntents
#if os(iOS)
import UIKit
#endif
import TelemetryDeck

@main
struct iGopherBrowserApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Bookmark.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
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
        configuration.analyticsDisabled = UserDefaults.standard.bool(forKey: "telemetryOptOut")
        TelemetryDeck.initialize(config: configuration)

#if os(iOS)
        // Set default link colour if none saved yet: light mode = system blue, dark mode = white
        if UserDefaults.standard.object(forKey: "linkColour") == nil {
            let isDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
            let uiColor: UIColor = isDark ? .white : .systemBlue
            let defaultColor = Color(uiColor)
            UserDefaults.standard.set(defaultColor.rawValue, forKey: "linkColour")
        }
#endif

        TelemetryDeck.signal("applicationDidFinishLaunching")
    }
}
