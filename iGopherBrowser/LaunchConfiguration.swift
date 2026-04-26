//
//  LaunchConfiguration.swift
//  iGopherBrowser
//

import Foundation

enum LaunchConfiguration {
    static func apply() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting") else { return }

        UserDefaults.standard.set(true, forKey: "telemetryOptOut")
        UserDefaults.standard.set(false, forKey: "crtMode")
        UserDefaults.standard.set(true, forKey: "hasFinishedFirstRunTips")
        UserDefaults.standard.set(WhatsNewConfig.currentVersion, forKey: "lastSeenWhatsNewVersion")

        if arguments.contains("-uiTestingShowWhatsNew") {
            UserDefaults.standard.set(true, forKey: "hasFinishedFirstRunTips")
            UserDefaults.standard.set("", forKey: "lastSeenWhatsNewVersion")
        }

        if arguments.contains("-uiTestingShowFirstRunTip") {
            UserDefaults.standard.set(false, forKey: "hasFinishedFirstRunTips")
            UserDefaults.standard.set(WhatsNewConfig.currentVersion, forKey: "lastSeenWhatsNewVersion")
        }

        if arguments.contains("-uiTestingCRTMode") {
            UserDefaults.standard.set(true, forKey: "crtMode")
            UserDefaults.standard.set(CRTPhosphorColor.amber.rawValue, forKey: "crtPhosphorColor")
        }

        if let index = arguments.firstIndex(of: "-uiTestHomeURL"),
           arguments.indices.contains(index + 1),
           let url = URL(string: arguments[index + 1]) {
            UserDefaults.standard.set(url, forKey: "homeURL")
        }
    }
}
