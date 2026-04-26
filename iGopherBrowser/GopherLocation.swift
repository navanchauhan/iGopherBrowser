//
//  GopherLocation.swift
//  iGopherBrowser
//

import Foundation

struct GopherLocation: Hashable, Identifiable, Sendable {
    let host: String
    let port: Int
    let selector: String

    var id: String { displayString }

    var displayString: String {
        "\(host):\(port)\(selector.normalizedGopherSelector)"
    }

    var gopherURL: URL {
        URL(string: "gopher://\(displayString)")!
    }

    init(host: String, port: Int = 70, selector: String = "/") {
        self.host = host.isEmpty ? "gopher.navan.dev" : host
        self.port = port

        let normalizedSelector = selector.normalizedGopherSelector
        self.selector = normalizedSelector.removingPercentEncoding ?? normalizedSelector
    }

    init(_ input: String, defaultPort: Int = 70, defaultHost: String = "gopher.navan.dev") {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.isEmpty == false else {
            self.init(host: defaultHost, port: defaultPort, selector: "/")
            return
        }

        if raw.contains("://"),
           let components = URLComponents(string: raw),
           let host = components.host {
            self.init(
                host: host,
                port: components.port ?? defaultPort,
                selector: components.percentEncodedPath.normalizedGopherSelector
            )
            return
        }

        let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let host = parts.first?.isEmpty == false ? parts[0] : defaultHost

        guard parts.count == 2 else {
            self.init(host: host, port: defaultPort, selector: "/")
            return
        }

        let portAndSelector = parts[1].split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let parsedPort = Int(portAndSelector.first ?? "") ?? defaultPort
        let parsedSelector = portAndSelector.count == 2 ? "/\(portAndSelector[1])" : "/"
        self.init(host: host, port: parsedPort, selector: parsedSelector)
    }
}

private extension String {
    var normalizedGopherSelector: String {
        if isEmpty { return "/" }
        return hasPrefix("/") ? self : "/\(self)"
    }
}
