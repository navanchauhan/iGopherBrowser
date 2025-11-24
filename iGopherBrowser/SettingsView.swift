//
//  SettingsView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/22/23.
//

import SwiftUI
import TelemetryDeck

extension Color: @retroactive RawRepresentable {

    public init?(rawValue: String) {

        guard let data = Data(base64Encoded: rawValue) else {
            self = .black
            return
        }

        do {
            #if os(macOS)
                let color =
                    (try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data))
                    ?? .black
            #else
                let color =
                    try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
                    ?? .black
            #endif
            self = Color(color)
        } catch {
            self = .black
        }

    }

    public var rawValue: String {

        do {
            #if os(macOS)
                let data =
                    try NSKeyedArchiver.archivedData(
                        withRootObject: NSColor(self), requiringSecureCoding: false) as Data
            #else
                let data =
                    try NSKeyedArchiver.archivedData(
                        withRootObject: UIColor(self), requiringSecureCoding: false) as Data
            #endif
            return data.base64EncodedString()

        } catch {

            return ""

        }

    }

}

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("accentColour", store: .standard) var accentColour: Color = Color(.blue)
    @AppStorage("linkColour", store: .standard) var linkColour: Color = Color(.white)
    @AppStorage("shareThroughProxy", store: .standard) var shareThroughProxy: Bool = true
    @AppStorage("telemetryOptOut", store: .standard) var telemetryOptOut: Bool = false

    // CRT Mode settings
    @AppStorage("crtMode") var crtMode: Bool = false
    @AppStorage("crtScanlines") var crtScanlines: Bool = true
    @AppStorage("crtVignette") var crtVignette: Bool = true
    @AppStorage("crtPhosphorColor") var crtPhosphorColor: String = CRTPhosphorColor.green.rawValue

    #if os(macOS)
        @AppStorage("homeURL") var homeURL: URL = URL(string: "gopher://gopher.navan.dev:70/")!
        @State var homeURLString: String = ""
    #else
        @Binding var homeURL: URL
        @Binding var homeURLString: String
    #endif
    @State private var showAlert = false
    @State private var alertMessage: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 0) {
            // Navigation section
            VStack(alignment: .leading, spacing: 12) {
                Text("Navigation")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home URL")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter home URL", text: $homeURLString)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .onSubmit {
                            if let url = URL(string: homeURLString) {
                                self.homeURL = url
                            }
                        }
                    
                    HStack(spacing: 8) {
                        Button("Save") {
                            if let url = URL(string: homeURLString) {
                                homeURL = url
                                print("Saved \(self.homeURL)")
                            } else {
                                self.alertMessage = "Unable to convert \(homeURLString) to a URL"
                                self.showAlert = true
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Reset to Default") {
                            self.homeURL = URL(string: "gopher://gopher.navan.dev:70/")!
                            self.homeURLString = "gopher://gopher.navan.dev:70/"
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
            }
            .padding(.bottom, 20)
            
            Divider()
            
            // Appearance section
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.headline)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ColorPicker("Link Color", selection: $linkColour)
                            .labelsHidden()
                        Text("Link Color")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        ColorPicker("Accent Color", selection: $accentColour)
                            .labelsHidden()
                        Text("Accent Color")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Button("Reset Colors") {
                            self.linkColour = Color(.white)
                            self.accentColour = Color(.blue)
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
            }
            .padding(.vertical, 20)

            Divider()

            // Retro Display section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tv")
                    Text("Retro Display")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("CRT Mode", isOn: $crtMode)

                    if crtMode {
                        HStack {
                            Text("Phosphor Color")
                            Spacer()
                            Picker("", selection: $crtPhosphorColor) {
                                ForEach(CRTPhosphorColor.allCases) { color in
                                    HStack {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 10, height: 10)
                                        Text(color.displayName)
                                    }
                                    .tag(color.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                        .padding(.leading, 20)

                        Toggle("Scanlines", isOn: $crtScanlines)
                            .padding(.leading, 20)
                        Toggle("Screen Vignette", isOn: $crtVignette)
                            .padding(.leading, 20)
                    }

                    Text("Enable 80s NASA vector-style CRT display with phosphor glow, scanlines, and vignette effects.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 20)

            Divider()
            
            // Privacy section
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Opt out of anonymous telemetry", isOn: $telemetryOptOut)
                        .onChange(of: telemetryOptOut) { _, newValue in
                            TelemetryDeck.terminate()
                            let cfg = TelemetryDeck.Config(appID: "400187ED-ADA9-4AB4-91F8-8825AD8FC67C")
                            cfg.analyticsDisabled = newValue
                            TelemetryDeck.initialize(config: cfg)
                        }
                    
                    Text("Opt out of anonymous telemetry that tracks crashes and random errors.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 20)
            
            Divider()
            
            // Share Settings section
            VStack(alignment: .leading, spacing: 12) {
                Text("Sharing")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Share links through HTTP(s) proxy", isOn: $shareThroughProxy)
                    
                    Text("Enabling this option shares Gopher URLs through an HTTP proxy, allowing people to view the page without needing a Gopher client.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 450, maxWidth: 550)
        .frame(minHeight: 500, maxHeight: 650)
        #else
        Form {
            Section(header: Text("Preferences")) {
                VStack {
                    TextField("Home URL", text: $homeURLString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                        .onSubmit {
                            if let url = URL(string: homeURLString) {
                                self.homeURL = url
                            }
                        }
                    HStack {
                        Button(
                            "Save",
                            action: {
                                if let url = URL(string: homeURLString) {
                                    homeURL = url
                                    print("Saved \(self.homeURL)")
                                    #if os(iOS)
                                        dismiss()
                                    #endif
                                } else {
                                    self.alertMessage =
                                        "Unable to convert \(homeURLString) to a URL"
                                    self.showAlert = true
                                }
                            })
                        Button(
                            "Reset Preferences",
                            action: {
                                self.homeURL = URL(string: "gopher://gopher.navan.dev:70/")!
                                #if os(iOS)
                                    dismiss()
                                #endif
                            })
                    }
                }
            }
            Section {
                Toggle("Opt out of anonymous telemetry", isOn: $telemetryOptOut)
                    .toggleStyle(.switch)
                    .onChange(of: telemetryOptOut) { _, newValue in
                        TelemetryDeck.terminate()
                        let cfg = TelemetryDeck.Config(appID: "400187ED-ADA9-4AB4-91F8-8825AD8FC67C")
                        cfg.analyticsDisabled = newValue
                        TelemetryDeck.initialize(config: cfg)
                    }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Opt out of anonymous telemetry that tracks crashes and random errors.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Section(header: Text("UI Settings")) {
                ColorPicker("Link Colour", selection: $linkColour)
                ColorPicker("Accent Colour", selection: $accentColour)
                Button("Reset Colours") {
                    #if os(iOS)
                        self.linkColour = colorScheme == .dark ? Color(.white) : Color(.systemBlue)
                    #else
                        self.linkColour = Color(.white)
                    #endif
                    self.accentColour = Color(.blue)
                }
            }

            Section {
                Toggle("CRT Mode", isOn: $crtMode)
                    .toggleStyle(.switch)

                if crtMode {
                    Picker("Phosphor Color", selection: $crtPhosphorColor) {
                        ForEach(CRTPhosphorColor.allCases) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                                Text(color.displayName)
                            }
                            .tag(color.rawValue)
                        }
                    }

                    Toggle("Scanlines", isOn: $crtScanlines)
                        .toggleStyle(.switch)
                    Toggle("Screen Vignette", isOn: $crtVignette)
                        .toggleStyle(.switch)
                }
            } header: {
                HStack {
                    Image(systemName: "tv")
                    Text("Retro Display")
                }
            } footer: {
                Text("Enable 80s NASA vector-style CRT display mode with phosphor glow, scanlines, and vignette effects.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Toggle("Share links through HTTP(s) proxy", isOn: $shareThroughProxy)
                    .toggleStyle(.switch)
            } header: {
                Text("Share Settings")
            } footer: {
                Text(
                    "Enabling this option shares Gopher URLs through an HTTP proxy, allowing people to view the page without needing a Gopher client"
                )
                .font(.caption)
                .foregroundColor(.gray)
            }
            #if os(visionOS)
                Button("Done") {
                    dismiss()
                }
            #endif
        }
        #endif
        }
        .onAppear {
            self.homeURLString = homeURL.absoluteString
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error Saving"),
                message: Text(alertMessage),
                dismissButton: .default(Text("Got it!"))
            )
        }
    }
}
