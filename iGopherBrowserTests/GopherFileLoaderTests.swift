import Foundation
import Testing
@testable import iGopherBrowser

struct GopherFileLoaderTests {
    @Test("Detects known file signatures")
    func detectsKnownFileSignatures() {
        #expect(determineFileType(data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) == "png")
        #expect(determineFileType(data: Data([0xFF, 0xD8, 0xFF])) == "jpeg")
        #expect(determineFileType(data: Data("%PDF-".utf8)) == "pdf")
        #expect(determineFileType(data: Data([0x00, 0x01, 0x02])) == nil)
    }

    @Test("Chunks text files and writes a temp file")
    func chunksTextFiles() throws {
        let data = (0..<205).map { "line-\($0)" }.joined(separator: "\n").data(using: .utf8)!
        let loaded = try GopherFileLoader.loadedFile(
            from: data,
            displayName: "about.txt",
            parsedTypeIsText: true
        )

        #expect(loaded.textChunks.count == 3)
        #expect(loaded.fileURL.pathExtension == "txt")
        #expect(FileManager.default.fileExists(atPath: loaded.fileURL.path))
    }
}
