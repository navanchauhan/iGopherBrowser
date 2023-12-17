//
//  FileView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//
import Foundation
import SwiftUI
import swiftGopherClient
import GopherHelpers
import QuickLook


func determineFileType(data: Data) -> String? {
    let signatures: [Data: String] = [
        Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]): "png",
        Data([0xFF, 0xD8, 0xFF]): "jpeg",
        Data("GIF87a".utf8): "gif",
        Data("GIF89a".utf8): "gif",
        Data("BM".utf8): "bmp",
        Data("%PDF-".utf8): "pdf",
        Data([0x50, 0x4B, 0x03, 0x04]): "docx",
        Data([0x50, 0x4B, 0x05, 0x06]): "docx",
        Data([0x50, 0x4B, 0x07, 0x08]): "docx",
        Data([0x49, 0x44, 0x33]): "mp3",
        Data([0x52, 0x49, 0x46, 0x46]): "wav",
        Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]): "mp4",
        Data([0x6D, 0x6F, 0x6F, 0x76]): "mov",
        // Add other file signatures as needed
    ]

    // Check for each signature
    for (signature, fileType) in signatures {
        if data.starts(with: signature) {
            return fileType
        }
    }
    
    return nil
}


struct FileView: View {
    var item: gopherItem
    let client = GopherClient()
    @State private var fileContent: String = "Loading..."
    @State private var fileURL: URL?
    @State private var QLURL: URL?
    
    let fileSignatures: [String: [UInt8]] = [
        "jpg": [0xFF, 0xD8, 0xFF],
        "png": [0x89, 0x50, 0x4E, 0x47],
        "gif": [0x47, 0x49, 0x46],
        "pdf": [0x25, 0x50, 0x44, 0x46],
    ]

    var body: some View {
        if item.parsedItemType == .text {
            ScrollView {
                Text(fileContent)
                    .onAppear {
                        readFile(item)
                    }
            }
        } else if [.doc, .image, .gif, .movie, .sound, .bitmap].contains(item.parsedItemType) { // Preview Document: .pdf, .docx, e.t.c
            // Quicklook
            if let url = fileURL {
                Button("Preview Document") {
                    print(url)
                    QLURL = url
                }.quickLookPreview($QLURL)
                        } else {
                            Text("Loading Document...")
                                .onAppear {
                                    readFile(item)
                                }
                        }
        }
    }

    private func readFile(_ item: gopherItem) {
        // Execute the network request on a background thread
            self.client.sendRequest(to: item.host, port: item.port, message: "\(item.selector)\r\n") { result in
                // Dispatch the result handling back to the main thread

                    switch result {
                    case .success(let resp):
                        if item.parsedItemType == .text {
                            if let firstLine = resp.first?.rawLine {
                                self.fileContent = firstLine
                            } else {
                                self.fileContent = "File is empty or couldn't be read."
                            }
                        } else {
                            if var data = resp.first?.rawData {
                                let tempDirURL = FileManager.default.temporaryDirectory
                                
                                do {
                                    var fileData = Data()
                                    print("Readable byees", data.readableBytes)
                                    while data.readableBytes > 0 {
                                        if let bytes = data.readBytes(length: data.readableBytes) {
                                            fileData.append(contentsOf: bytes)
                                        }
                                    }
                                    
                                    let fileURL = tempDirURL.appendingPathComponent(UUID().uuidString + ".\(determineFileType(data: fileData) ?? "unkown")")
                                    print(fileURL)
                                    try fileData.write(to: fileURL)
                                    self.fileURL = fileURL
                                } catch {
                                    print("Error writing file to temp directory: \(error)")
                                }
                            }
                        }
                    case .failure(_):
                        self.fileContent = "Unable to fetch file due to network error."
                    }
                }
            
        
    }
    
    private func getTempFileURL(_ data: [UInt8]) -> URL? {
        let tempDirURL = FileManager.default.temporaryDirectory
        let fileURL = tempDirURL.appendingPathComponent(UUID().uuidString + ".pdf")
        print(fileURL)
        do {
            let fileData = Data(data)
            try fileData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing file to temp directory: \(error)")
            return nil
        }
    }
}
