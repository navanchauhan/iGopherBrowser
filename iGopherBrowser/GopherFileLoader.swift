//
//  GopherFileLoader.swift
//  iGopherBrowser
//

import Foundation
import GopherHelpers
import NIOCore
import SwiftGopherClient

struct LoadedGopherFile {
    let fileURL: URL
    let data: Data
    let textChunks: [String]
}

struct GopherFileLoader {
    private let client = GopherClient()

    func load(_ item: gopherItem) async throws -> LoadedGopherFile {
        let response = try await client.sendRequest(
            to: item.host,
            port: item.port,
            message: "\(item.selector)\r\n"
        )
        guard var buffer = response.first?.rawData else {
            throw CocoaError(.fileReadUnknown)
        }

        var data = Data()
        while buffer.readableBytes > 0 {
            try Task.checkCancellation()
            if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                data.append(contentsOf: bytes)
            }
        }

        return try Self.loadedFile(
            from: data,
            displayName: item.message,
            parsedTypeIsText: item.parsedItemType == .text
        )
    }

    static func loadedFile(
        from data: Data,
        displayName: String,
        parsedTypeIsText: Bool
    ) throws -> LoadedGopherFile {
        let fileExtension = parsedTypeIsText ? "txt" : determineFileType(data: data) ?? "unknown"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString).\(fileExtension)"
        )
        try data.write(to: fileURL)

        let chunks: [String]
        if parsedTypeIsText, let string = String(data: data, encoding: .utf8) {
            let lines = string.components(separatedBy: .newlines)
            chunks = stride(from: 0, to: lines.count, by: 100).map {
                lines[$0..<min($0 + 100, lines.count)].joined(separator: "\n")
            }
        } else {
            chunks = []
        }

        return LoadedGopherFile(fileURL: fileURL, data: data, textChunks: chunks)
    }
}
