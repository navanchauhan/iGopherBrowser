//
//  iGopherBrowserApp.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI
import SwiftData
import AppIntents
#if canImport(UIKit)
import UIKit
#endif
import TelemetryDeck

@main
struct iGopherBrowserApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Bookmark.self, HistoryItem.self])
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
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
        LaunchConfiguration.apply()

        Telemetry.start(optOut: UserDefaults.standard.bool(forKey: SettingsKey.telemetryOptOut))

        // Default CRT experience for brand-new installs
        if UserDefaults.standard.object(forKey: SettingsKey.crtMode) == nil {
            UserDefaults.standard.set(SettingsDefault.crtMode, forKey: SettingsKey.crtMode)
            UserDefaults.standard.set(
                SettingsDefault.crtPhosphorColor.rawValue,
                forKey: SettingsKey.crtPhosphorColor)
        }

#if canImport(UIKit)
        // Set default link colour if none saved yet: light mode = system blue, dark mode = white
        if UserDefaults.standard.object(forKey: SettingsKey.linkColour) == nil {
            let uiColor = UIColor { traits in
                traits.userInterfaceStyle == .dark ? .white : .systemBlue
            }
            let defaultColor = Color(uiColor)
            UserDefaults.standard.set(defaultColor.rawValue, forKey: SettingsKey.linkColour)
        }
#endif

        TelemetryDeck.signal("applicationDidFinishLaunching")
    }
}
