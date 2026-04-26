import Foundation
import Network

final class GopherFixtureServer {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "GopherFixtureServer")

    var port: UInt16 {
        listener.port!.rawValue
    }

    init() throws {
        listener = try NWListener(using: .tcp, on: 0)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
    }

    deinit {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
            let selector = data.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .newlines) ?? "/"
            let response = Self.response(for: selector, port: self.port)
            let sendResponse = {
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }

            if selector == "/slow" {
                self.queue.asyncAfter(deadline: .now() + 1.5, execute: sendResponse)
            } else {
                sendResponse()
            }
        }
    }

    private static func response(for selector: String, port: UInt16) -> Data {
        switch selector {
        case "", "/":
            return menu([
                "iWelcome to Fixture Gopher\tfake\tlocalhost\t\(port)",
                "1Documents\t/docs\t127.0.0.1\t\(port)",
                "0About Fixture\t/about.txt\t127.0.0.1\t\(port)",
                "7Search Server\t/search\t127.0.0.1\t\(port)",
                "IImage Fixture\t/image.png\t127.0.0.1\t\(port)",
                "9Binary Fixture\t/binary.bin\t127.0.0.1\t\(port)",
                "3Unknown Fixture\t/unknown\t127.0.0.1\t\(port)",
                "1Slow Directory\t/slow\t127.0.0.1\t\(port)",
                "hHTTP Link\tURL:https://example.com\t127.0.0.1\t\(port)"
            ])
        case "/docs":
            return menu([
                "iNested directory\tfake\tlocalhost\t\(port)",
                "0Read Me\t/readme.txt\t127.0.0.1\t\(port)"
            ])
        case "/about.txt":
            return Data("About Fixture\nSwiftUI browser content\nFindable needle\n".utf8)
        case "/readme.txt":
            return Data("Nested document\n".utf8)
        case "/search\tpython":
            return menu([
                "0Python Result\t/python.txt\t127.0.0.1\t\(port)"
            ])
        case "/python.txt":
            return Data("Python search result\n".utf8)
        case "/image.png":
            return Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/luzmAAAAAABJRU5ErkJggg==")!
        case "/binary.bin":
            return Data("RAW BINARY PAYLOAD".utf8)
        case "/slow":
            return menu([
                "iSlow response complete\tfake\tlocalhost\t\(port)"
            ])
        default:
            return menu(["iNot found: \(selector)\tfake\tlocalhost\t\(port)"])
        }
    }

    private static func menu(_ lines: [String]) -> Data {
        Data((lines.joined(separator: "\r\n") + "\r\n.\r\n").utf8)
    }
}
