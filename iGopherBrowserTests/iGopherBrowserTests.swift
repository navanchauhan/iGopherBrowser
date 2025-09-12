import XCTest
@testable import iGopherBrowser
import SwiftUI

final class iGopherBrowserTests: XCTestCase {

    func testGetHostAndPort_withFullURL() {
        let res = getHostAndPort(from: "gopher://example.com:70/some/path")
        XCTAssertEqual(res.host, "example.com")
        XCTAssertEqual(res.port, 70)
        XCTAssertEqual(res.selector, "/some/path")
    }

    func testGetHostAndPort_simpleHostPortAndPath() {
        let res = getHostAndPort(from: "localhost:7070/some/dir")
        XCTAssertEqual(res.host, "localhost")
        XCTAssertEqual(res.port, 7070)
        XCTAssertEqual(res.selector, "/some/dir")
    }

    func testGetHostAndPort_defaultsApplied() {
        let res = getHostAndPort(from: "just-a-hostname")
        XCTAssertEqual(res.host, "just-a-hostname")
        XCTAssertEqual(res.port, 70)
        XCTAssertEqual(res.selector, "/")
    }

    func testGetHostAndPort_portAndSelectorFallback() {
        // invalid port, but selector should still be parsed
        let res = getHostAndPort(from: "example.org:x/path", defaultPort: 72)
        XCTAssertEqual(res.host, "example.org")
        XCTAssertEqual(res.port, 72) // fallback to default
        XCTAssertEqual(res.selector, "/path")
    }

    func testDetermineFileType_signatures() {
        // PNG
        XCTAssertEqual(determineFileType(data: Data([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A])), "png")
        // JPEG
        XCTAssertEqual(determineFileType(data: Data([0xFF,0xD8,0xFF])), "jpeg")
        // GIF87a
        XCTAssertEqual(determineFileType(data: Data("GIF87a".utf8)), "gif")
        // GIF89a
        XCTAssertEqual(determineFileType(data: Data("GIF89a".utf8)), "gif")
        // BMP
        XCTAssertEqual(determineFileType(data: Data("BM".utf8)), "bmp")
        // PDF
        XCTAssertEqual(determineFileType(data: Data("%PDF-".utf8)), "pdf")
        // DOCX (zip header variants)
        XCTAssertEqual(determineFileType(data: Data([0x50,0x4B,0x03,0x04])), "docx")
        XCTAssertEqual(determineFileType(data: Data([0x50,0x4B,0x05,0x06])), "docx")
        XCTAssertEqual(determineFileType(data: Data([0x50,0x4B,0x07,0x08])), "docx")
        // MP3
        XCTAssertEqual(determineFileType(data: Data([0x49,0x44,0x33])), "mp3")
        // WAV
        XCTAssertEqual(determineFileType(data: Data([0x52,0x49,0x46,0x46])), "wav")
        // MP4
        XCTAssertEqual(determineFileType(data: Data([0x00,0x00,0x00,0x18,0x66,0x74,0x79,0x70])), "mp4")
        // MOV
        XCTAssertEqual(determineFileType(data: Data([0x6D,0x6F,0x6F,0x76])), "mov")
        // GZIP
        XCTAssertEqual(determineFileType(data: Data([0x1F,0x8B])), "gz")
        // Unknown
        XCTAssertNil(determineFileType(data: Data([0x00,0x01,0x02,0x03])))
    }

    func testColorRawRepresentable_roundTrip() {
        let original = Color(.sRGB, red: 0.2, green: 0.4, blue: 0.6, opacity: 1.0)
        let encoded = original.rawValue
        XCTAssertFalse(encoded.isEmpty)
        let decoded = Color(rawValue: encoded)
        XCTAssertNotNil(decoded)
        // Round-tripping back to string should be stable
        XCTAssertEqual(decoded?.rawValue, encoded)
    }

    func testColorRawRepresentable_invalidData() {
        // invalid base64 should fall back to black per implementation
        let decoded = Color(rawValue: "not-base64!")
        XCTAssertNotNil(decoded)
    }

    // MARK: - SwiftUI Views basic coverage

    func testSearchInputView_buildsBody_andCallsOnSearch() {
        var captured: String? = nil
        var text = "hello"
        let view = SearchInputView(
            host: "example.com",
            port: 70,
            selector: "/",
            searchText: .init(get: { text }, set: { text = $0 }),
            onSearch: { captured = $0 }
        )
        // Force compute of the body to exercise layout code
        _ = view.body
        // Directly invoke the provided callback to validate plumbing
        view.onSearch("query")
        XCTAssertEqual(captured, "query")
        // Sanity check initial properties
        XCTAssertEqual(view.host, "example.com")
        XCTAssertEqual(view.port, 70)
        XCTAssertEqual(view.selector, "/")
    }

    func testBookmarksView_buildsBody() {
        let view = BookmarksView()
        _ = view.body
        // No runtime crash indicates layout builds successfully
        XCTAssertTrue(true)
    }

    func testSidebarView_buildsBody_andOnSelect() {
        let leaf = GopherNode(host: "h", port: 70, selector: "/a", message: "Leaf", item: nil, children: nil)
        let root = GopherNode(host: "h", port: 70, selector: "/", message: "Root", item: nil, children: [leaf])
        var selected: GopherNode? = nil
        let view = SidebarView(hosts: [root]) { node in selected = node }
        _ = view.body
        // Manually call the selection closure to validate wiring
        view.onSelect(leaf)
        XCTAssertEqual(selected, leaf)
    }
}
