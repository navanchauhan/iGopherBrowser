//
//  Telemetry.swift
//  iGopherBrowser
//

import Foundation
import TelemetryDeck

enum Telemetry {
    private static let appID = "400187ED-ADA9-4AB4-91F8-8825AD8FC67C"

    static func start(optOut: Bool) {
        let configuration = TelemetryDeck.Config(appID: appID)
        configuration.analyticsDisabled = optOut
        TelemetryDeck.initialize(config: configuration)
    }

    static func restart(optOut: Bool) {
        TelemetryDeck.terminate()
        start(optOut: optOut)
    }
}
