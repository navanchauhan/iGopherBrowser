import Testing
@testable import iGopherBrowser

struct GopherLocationTests {
    @Test(
        "Parses common gopher location inputs",
        arguments: [
            ("gopher://example.com:70/some/path", 70, "example.com", 70, "/some/path"),
            ("localhost:7070/some/dir", 70, "localhost", 7070, "/some/dir"),
            ("just-a-hostname", 70, "just-a-hostname", 70, "/"),
            ("example.org:x/path", 72, "example.org", 72, "/path"),
            ("gopher://example.com/search%09python", 70, "example.com", 70, "/search\tpython")
        ]
    )
    func parsesInputs(
        input: String,
        defaultPort: Int,
        host: String,
        port: Int,
        selector: String
    ) {
        let location = GopherLocation(input, defaultPort: defaultPort)
        #expect(location.host == host)
        #expect(location.port == port)
        #expect(location.selector == selector)
    }

    @Test("Formats display and URL strings consistently")
    func formatsStrings() {
        let location = GopherLocation(host: "example.com", port: 70, selector: "/about")
        #expect(location.displayString == "example.com:70/about")
        #expect(location.gopherURL.absoluteString == "gopher://example.com:70/about")
    }
}
