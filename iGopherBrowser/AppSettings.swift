//
//  AppSettings.swift
//  iGopherBrowser
//

import Foundation
import SwiftUI

enum SettingsKey {
    static let homeURL = "homeURL"
    static let accentColour = "accentColour"
    static let linkColour = "linkColour"
    static let shareThroughProxy = "shareThroughProxy"
    static let telemetryOptOut = "telemetryOptOut"
    static let crtMode = "crtMode"
    static let crtScanlines = "crtScanlines"
    static let crtVignette = "crtVignette"
    static let crtPhosphorColor = "crtPhosphorColor"
    static let hasFinishedFirstRunTips = "hasFinishedFirstRunTips"
    static let lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"
}

enum SettingsDefault {
    static let host = "gopher.navan.dev"
    static let port = 70
    static let homeURLString = "gopher://\(host):\(port)/"
    static let homeURL = URL(string: homeURLString)!
    static let accentColour = Color.blue
    static let linkColour = Color.white
    static let shareThroughProxy = true
    static let crtMode = true
    static let crtScanlines = true
    static let crtVignette = true
    static let crtPhosphorColor = CRTPhosphorColor.amber
}

/// Read-only view of the CRT display preferences, resolved into colours.
struct CRTStyle {
    let isEnabled: Bool
    let phosphor: Color

    /// Body text colour, falling back to `base` when CRT mode is off.
    func text(_ base: Color = .primary) -> Color {
        isEnabled ? phosphor : base
    }

    /// Link colour, falling back to the user's configured link colour.
    func link(_ base: Color) -> Color {
        isEnabled ? phosphor : base
    }
}

/// Exposes `CRTStyle` to a view, tracking the underlying defaults like `@AppStorage` does.
@propertyWrapper
struct CRTAppearance: DynamicProperty {
    @AppStorage(SettingsKey.crtMode) private var isEnabled: Bool = SettingsDefault.crtMode
    @AppStorage(SettingsKey.crtPhosphorColor) private var phosphorRaw: String =
        SettingsDefault.crtPhosphorColor.rawValue

    var wrappedValue: CRTStyle {
        CRTStyle(
            isEnabled: isEnabled,
            phosphor: (CRTPhosphorColor(rawValue: phosphorRaw) ?? SettingsDefault.crtPhosphorColor).color
        )
    }
}

extension View {
    /// Phosphor glow applied to text while CRT mode is on.
    func crtGlow(_ style: CRTStyle, color: Color) -> some View {
        shadow(color: style.isEnabled ? color.opacity(0.5) : .clear, radius: style.isEnabled ? 2 : 0)
    }
}
