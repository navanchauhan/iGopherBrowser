//
//  iGopherBrowserApp.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI

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
  }
}
