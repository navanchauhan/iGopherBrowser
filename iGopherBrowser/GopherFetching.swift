//
//  GopherFetching.swift
//  iGopherBrowser
//

import GopherHelpers
import SwiftGopherClient

protocol GopherFetching {
    func fetch(_ location: GopherLocation) async throws -> [gopherItem]
}

struct LiveGopherFetcher: GopherFetching {
    private let client = GopherClient()

    func fetch(_ location: GopherLocation) async throws -> [gopherItem] {
        try await client.sendRequest(
            to: location.host,
            port: location.port,
            message: "\(location.selector)\r\n"
        )
    }
}

protocol GopherResponseCaching {
    func cachedItems(for location: GopherLocation) -> [gopherItem]?
    func store(_ items: [gopherItem], for location: GopherLocation)
}

struct NoGopherResponseCache: GopherResponseCaching {
    func cachedItems(for location: GopherLocation) -> [gopherItem]? { nil }
    func store(_ items: [gopherItem], for location: GopherLocation) {}
}
