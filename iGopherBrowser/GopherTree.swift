//
//  GopherTree.swift
//  iGopherBrowser
//

import Foundation
import GopherHelpers

/// Builds the sidebar tree of visited hosts and the pages discovered under them.
struct GopherTree {
    private static let childLimit = 200

    private(set) var hosts: [GopherNode]

    init(hosts: [GopherNode] = []) {
        self.hosts = hosts
    }

    mutating func merge(_ response: [GopherItem], for location: GopherLocation) {
        let childNodes = Self.children(from: response)

        guard let index = hosts.firstIndex(where: { $0.host == location.host && $0.port == location.port })
        else {
            hosts.append(Self.rootNode(for: location, children: childNodes))
            return
        }

        if Self.isRoot(location) {
            hosts[index].selector = "/"
            hosts[index].message = location.host
            hosts[index].children = childNodes
            return
        }

        let title = Self.existingTitle(for: location, in: hosts[index]) ?? Self.title(for: location)
        let page = GopherNode(
            host: location.host,
            port: location.port,
            selector: location.selector,
            message: title,
            item: nil,
            children: childNodes
        )
        hosts[index].children = Self.upserting(page, into: hosts[index].children ?? [])
    }

    private static func rootNode(for location: GopherLocation, children: [GopherNode]) -> GopherNode {
        let rootChildren: [GopherNode]
        if isRoot(location) {
            rootChildren = children
        } else {
            rootChildren = [
                GopherNode(
                    host: location.host,
                    port: location.port,
                    selector: location.selector,
                    message: title(for: location),
                    item: nil,
                    children: children
                )
            ]
        }

        return GopherNode(
            host: location.host,
            port: location.port,
            selector: "/",
            message: location.host,
            item: nil,
            children: rootChildren
        )
    }

    private static func children(from response: [GopherItem]) -> [GopherNode] {
        let nodes = response.compactMap { item -> GopherNode? in
            guard item.parsedItemType != .info else { return nil }
            return GopherNode(
                host: item.host,
                port: item.port,
                selector: item.selector,
                message: item.message,
                item: item,
                children: nil
            )
        }

        guard nodes.count <= childLimit else { return [] }

        var seen = Set<String>()
        return nodes.filter { seen.insert($0.id).inserted }
    }

    private static func upserting(_ node: GopherNode, into children: [GopherNode]) -> [GopherNode] {
        var result = children
        if let index = result.firstIndex(where: { $0.id == node.id }) {
            result[index] = node
        } else {
            result.append(node)
        }
        return result
    }

    private static func existingTitle(for location: GopherLocation, in root: GopherNode) -> String? {
        let locationID = GopherNode(
            host: location.host,
            port: location.port,
            selector: location.selector,
            message: nil,
            item: nil,
            children: nil
        ).id

        return root.children?.first(where: { $0.id == locationID })?.message
    }

    private static func isRoot(_ location: GopherLocation) -> Bool {
        GopherLocation.normalizedSelector(location.selector) == "/"
    }

    private static func title(for location: GopherLocation) -> String {
        let selector = GopherLocation.normalizedSelector(location.selector)
        return selector == "/" ? location.host : selector
    }
}
