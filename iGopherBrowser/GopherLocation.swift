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

    /// Percent encoded form, safe to feed to `URL(string:)`.
    private var encodedDisplayString: String {
        let encodedSelector = selector.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? selector.normalizedGopherSelector
        return "\(host):\(port)\(encodedSelector)"
    }

    var gopherURL: URL {
        URL(string: "gopher://\(encodedDisplayString)") ?? SettingsDefault.homeURL
    }

    /// URL handed to the share sheet, optionally routed through the HTTP proxy so that
    /// recipients without a Gopher client can still open it.
    func shareURL(throughProxy: Bool) -> URL {
        guard throughProxy else { return gopherURL }
        return URL(string: "https://\(SettingsDefault.host)/\(encodedDisplayString)") ?? gopherURL
    }

    static func normalizedSelector(_ selector: String) -> String {
        selector.normalizedGopherSelector
    }

    init(host: String, port: Int = SettingsDefault.port, selector: String = "/") {
        self.host = host.isEmpty ? SettingsDefault.host : host
        self.port = port

        let normalizedSelector = selector.normalizedGopherSelector
        self.selector = normalizedSelector.removingPercentEncoding ?? normalizedSelector
    }

    init(_ input: String, defaultPort: Int = SettingsDefault.port, defaultHost: String = SettingsDefault.host) {
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

extension String {
    var normalizedGopherSelector: String {
        if isEmpty { return "/" }
        return hasPrefix("/") ? self : "/\(self)"
    }
}
