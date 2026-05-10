//
//  LaunchConfiguration.swift
//  iGopherBrowser
//

import Foundation

enum LaunchConfiguration {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    static var shouldAutoLoadHome: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestingAutoLoadHome")
    }

    static var shouldSeedDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestingSeedDemoData")
    }

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

        if let url = homeURL(from: arguments) {
            UserDefaults.standard.set(url, forKey: "homeURL")
        }
    }

    private static func homeURL(from arguments: [String]) -> URL? {
        if let index = arguments.firstIndex(of: "-uiTestHomeURL"),
           arguments.indices.contains(index + 1),
           let url = URL(string: arguments[index + 1].removingPercentEncoding ?? arguments[index + 1]) {
            return url
        }

        guard let host = value(after: "-uiTestHomeHost", in: arguments) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "gopher"
        components.host = host
        components.port = Int(value(after: "-uiTestHomePort", in: arguments) ?? "70")
        components.path = value(after: "-uiTestHomeSelector", in: arguments) ?? ""
        return components.url
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }

        return arguments[index + 1]
    }
}
