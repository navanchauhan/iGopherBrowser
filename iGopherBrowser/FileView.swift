//
//  FileView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//
import Foundation
import SwiftUI

import swiftGopherClient

struct FileView: View {
    var item: gopherItem
    let client = GopherClient()
    @State private var fileContent: String = "Loading..."
    @Environment(\.dismiss) var dismiss

    var body: some View {
        if item.parsedItemType == .text {
            ScrollView {
                Text(fileContent)
                    .onAppear {
                        readFile(item)
                    }
            } .toolbar {
                ToolbarItem() {
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Back", systemImage: "arrow.left.circle")
                    }
                }
            }
        }
    }

    private func readFile(_ item: gopherItem) {
        // Execute the network request on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.client.sendRequest(to: item.host, port: item.port, message: "\(item.selector)\r\n") { result in
                // Dispatch the result handling back to the main thread
                DispatchQueue.main.async {
                    switch result {
                    case .success(let resp):
                        if let firstLine = resp.first?.rawLine {
                            self.fileContent = firstLine
                        } else {
                            self.fileContent = "File is empty or couldn't be read."
                        }
                    case .failure(_):
                        self.fileContent = "Unable to fetch file due to network error."
                    }
                }
            }
        }
    }
}
