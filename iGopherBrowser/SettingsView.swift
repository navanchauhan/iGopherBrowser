//
//  SettingsView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/22/23.
//

import SwiftUI

struct SettingsView: View {
  #if os(iOS)
    @Binding var homeURL: URL
    @Binding var homeURLString: String
  #endif
  #if os(macOS)
    @AppStorage("homeURL") var homeURL: URL = URL(string: "gopher://gopher.navan.dev:70/")!
    @State var homeURLString: String = ""
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
    }
    #if os(OSX)
      .padding(20)
      .frame(width: 350, height: 100)
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
