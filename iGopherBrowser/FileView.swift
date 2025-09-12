//
//  FileView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//
import Foundation
import GopherHelpers
import QuickLook
import SwiftGopherClient
import SwiftUI
import TelemetryDeck
#if os(macOS)
import AppKit
#endif

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

    // Debug file signatures
    //    for byte in data.prefix(10) {
    //        print(String(format: "%02x", byte), terminator: " ")
    //    }

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
    @State private var fileContent: [String] = []
    @State private var fileURL: URL?
    @State private var QLURL: URL?
    @State private var downloadedData: Data?
    @State private var isSaving: Bool = false
    @State private var showRawUnknown: Bool = false

    var body: some View {
        if item.parsedItemType == .text {
            GeometryReader { _ in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        filenameLabel()
                        Spacer()
                        if let _ = fileURL {
                            downloadControl()
                        }
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(fileContent.indices, id: \.self) { index in
                                Text(fileContent[index])
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .task { readFile(item) }
            .listStyle(PlainListStyle())
        } else if [.doc, .image, .gif, .movie, .sound, .bitmap].contains(item.parsedItemType) {  // Preview Document: .pdf, .docx, e.t.c
            // QuickLook + Download
            if let url = fileURL {
                VStack(alignment: .leading, spacing: 12) {
                    filenameLabel()
                    Button("Preview Document") {
                        print(url)
                        QLURL = url
                    }.quickLookPreview($QLURL)
                    downloadControl()
                }
            } else {
                Text("Loading Document...")
                    .onAppear { readFile(item) }
            }
        } else {
            // Unknown type: offer two options — Show Raw and Save As
            if let _ = fileURL {
                VStack(alignment: .leading, spacing: 12) {
                    filenameLabel()
                    HStack(spacing: 12) {
                        Button(showRawUnknown ? "Hide Raw" : "Show Raw") {
                            showRawUnknown.toggle()
                        }
                        downloadControl(label: "Save As…")
                    }
                    if showRawUnknown, let data = downloadedData {
                        ScrollView {
                            Text(rawText(from: data))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 400)
                    }
                }
                .padding()
            } else {
                Text("Loading...")
                    .onAppear { readFile(item) }
            }
        }
    }

    private func readFile(_ item: gopherItem) {
        self.client.sendRequest(to: item.host, port: item.port, message: "\(item.selector)\r\n") {
            result in
            // Dispatch the result handling back to the main thread
            switch result {
            case .success(let resp):
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
                        print("Read entire file")
                        if item.parsedItemType == .text {
                            print("parsing string file")
                            if let string = String(data: fileData, encoding: .utf8) {
                                print("updating state")
                                let lines = string.components(separatedBy: .newlines)
                                let chunkSize = 100
                                self.fileContent = stride(from: 0, to: lines.count, by: chunkSize)
                                    .map {
                                        lines[$0..<min($0 + chunkSize, lines.count)].joined(
                                            separator: "\n")
                                    }
                                // Also persist a temporary text file to enable Save/Share
                                let textURL = tempDirURL.appendingPathComponent(
                                    UUID().uuidString + ".txt")
                                try fileData.write(to: textURL)
                                self.fileURL = textURL
                                self.downloadedData = fileData
                            } else {
                                print("Could not get file")
                            }
                            return
                        }
                        let fileURL = tempDirURL.appendingPathComponent(
                            UUID().uuidString + ".\(determineFileType(data: fileData) ?? "unkown")")
                        print(fileURL)

                        if determineFileType(data: fileData) == nil {
                            TelemetryDeck.signal(
                                "applicationUnableToDetectFiletype",
                                parameters: ["gopherURL": "\(item.host):\(item.port)\(item.selector)"])
                        }

                        try fileData.write(to: fileURL)
                        self.fileURL = fileURL
                        self.downloadedData = fileData
                    } catch {
                        print("Error writing file to temp directory: \(error)")
                    }
                }
            case .failure(_):
                self.fileContent = ["Unable to fetch file due to network error."]
            }
        }

    }

    // MARK: - Download / Save helpers
    @ViewBuilder
    private func downloadControl(label: String? = nil) -> some View {
        if let url = fileURL {
            #if os(macOS)
            Button {
                saveFile(from: url)
            } label: {
                Label(label ?? "Save As…", systemImage: "square.and.arrow.down")
            }
            .disabled(isSaving)
            #else
            ShareLink(item: url) {
                Label(label ?? "Save As…", systemImage: "square.and.arrow.up")
            }
            #endif
        }
    }

    #if os(macOS)
    private func saveFile(from tempURL: URL) {
        isSaving = true
        defer { isSaving = false }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultFileName(basedOn: tempURL)
        if panel.runModal() == .OK, let destURL = panel.url {
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: tempURL, to: destURL)
                TelemetryDeck.signal("applicationSavedFile", parameters: [
                    "file": destURL.lastPathComponent
                ])
            } catch {
                print("Failed to save file: \(error)")
            }
        }
    }

    private func defaultFileName(basedOn tempURL: URL) -> String {
        let baseExt = tempURL.pathExtension.isEmpty ? "bin" : tempURL.pathExtension
        var base = item.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "download" }
        // Remove path separators and illegal characters
        let invalid = CharacterSet(charactersIn: "/\\?%*|:\"<>\n\r")
        base = base.components(separatedBy: invalid).joined(separator: "-")
        if base.lowercased().hasSuffix(".\(baseExt.lowercased())") {
            return base
        } else {
            return "\(base).\(baseExt)"
        }
    }
    #endif

    // MARK: - UI helpers
    @ViewBuilder
    private func filenameLabel() -> some View {
        if let url = fileURL {
            HStack(spacing: 8) {
                Image(systemName: "doc")
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else {
            EmptyView()
        }
    }

    private func rawText(from data: Data) -> String {
        if let string = String(data: data, encoding: .utf8), string.isEmpty == false {
            return string
        }
        // Fallback to hex representation
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
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
