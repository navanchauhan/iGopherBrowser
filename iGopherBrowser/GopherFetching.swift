//
//  GopherFetching.swift
//  iGopherBrowser
//

import GopherHelpers
import SwiftGopherClient

protocol GopherFetching {
    func fetch(_ location: GopherLocation) async throws -> [GopherItem]
}

struct LiveGopherFetcher: GopherFetching {
    private let client = GopherClient()

    func fetch(_ location: GopherLocation) async throws -> [GopherItem] {
        try await client.sendRequest(
            to: location.host,
            port: location.port,
            message: "\(location.selector)\r\n"
        )
    }
}

protocol GopherResponseCaching {
    func cachedItems(for location: GopherLocation) -> [GopherItem]?
    func store(_ items: [GopherItem], for location: GopherLocation)
}

struct NoGopherResponseCache: GopherResponseCaching {
    func cachedItems(for location: GopherLocation) -> [GopherItem]? { nil }
    func store(_ items: [GopherItem], for location: GopherLocation) {}
}
