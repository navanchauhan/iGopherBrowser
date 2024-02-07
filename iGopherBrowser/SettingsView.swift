//
//  SettingsView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/22/23.
//

import SwiftUI

extension Color: RawRepresentable {

  public init?(rawValue: String) {

    guard let data = Data(base64Encoded: rawValue) else {
      self = .black
      return
    }

    do {
      #if os(macOS)
        let color =
          try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSColor ?? .black
      #else
        let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) ?? .black
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

  @AppStorage("accentColour", store: .standard) var accentColour: Color = Color(.blue)
  @AppStorage("linkColour", store: .standard) var linkColour: Color = Color(.white)

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
    Form {
      Section(header: Text("Preferences")) {
        VStack {
          TextField("Home URL", text: $homeURLString)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .disableAutocorrection(true)
            //            .onAppear {
            //              // Convert URL to String when the view appears
            //              self.homeURLString = homeURL.absoluteString
            //            }
            .onSubmit {
              // Convert String back to URL when the user submits the text
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
                  self.alertMessage = "Unable to convert \(homeURLString) to a URL"
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
      Section(header: Text("UI Settings")) {
        ColorPicker("Link Colour", selection: $linkColour)
        ColorPicker("Accent Colour", selection: $accentColour)
        Button("Reset Colours") {
          self.linkColour = Color(.white)
          self.accentColour = Color(.blue)
        }
      }
      #if os(visionOS)
        Button("Done") {
          dismiss()
        }
      #endif
    }
    #if os(OSX)
      .padding(20)
      .frame(width: 350, height: 350)
    #endif
    .alert(isPresented: $showAlert) {
      Alert(
        title: Text("Error Saving"),
        message: Text(alertMessage),
        dismissButton: .default(Text("Got it!"))
      )
    }
  }
}
