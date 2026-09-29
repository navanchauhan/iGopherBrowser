//
//  GopherNode.swift
//  iGopherBrowser
//

import Foundation
import GopherHelpers

/// A node of the sidebar tree. Mirrors a location plus the items discovered underneath it.
struct GopherNode: Identifiable, Equatable {
    static func == (lhs: GopherNode, rhs: GopherNode) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port && lhs.selector == rhs.selector
    }

    var id: String {
        "\(host):\(port):\(GopherLocation.normalizedSelector(selector))"
    }

    var host: String
    let port: Int
    var selector: String
    var message: String?
    let item: GopherItem?
    var children: [GopherNode]?
}
