//
//  BrowserSession.swift
//  iGopherBrowser
//

import Foundation
import GopherHelpers
import OmniUICore

@MainActor
@OmniUICore.Observable
final class BrowserSession {
    private static let sidebarChildLimit = 200

    var urlText = ""
    var items: [gopherItem] = []
    var hosts: [GopherNode] = []
    var currentLocation: GopherLocation?
    var backwardStack: [GopherLocation] = []
    var forwardStack: [GopherLocation] = []
    var searchContext: SearchContext?
    var findText = ""
    var currentFindIndex = 0
    var isLoading = false
    var errorMessage: String?

    @OmniUICore.ObservationIgnored private let fetcher: any GopherFetching
    @OmniUICore.ObservationIgnored private let cache: any GopherResponseCaching
    @OmniUICore.ObservationIgnored private var currentTask: Task<Void, Never>?
    @OmniUICore.ObservationIgnored private var requestID = UUID()

    var findMatches: [Int] {
        guard findText.isEmpty == false else { return [] }
        return items.enumerated().compactMap { index, item in
            item.message.localizedCaseInsensitiveContains(findText) ? index : nil
        }
    }

    init(
        fetcher: any GopherFetching = LiveGopherFetcher(),
        cache: any GopherResponseCaching = NoGopherResponseCache()
    ) {
        self.fetcher = fetcher
        self.cache = cache
    }

    deinit {
        currentTask?.cancel()
    }

    func load(_ location: GopherLocation, clearForward: Bool = true) async {
        guard let normalized = normalizedSearchLocation(location) else {
            isLoading = false
            return
        }

        currentTask?.cancel()
        requestID = UUID()
        let activeRequestID = requestID

        urlText = normalized.displayString
        currentLocation = normalized
        isLoading = true
        errorMessage = nil

        if let cachedItems = cache.cachedItems(for: normalized) {
            apply(cachedItems, for: normalized, clearForward: clearForward)
            isLoading = false
            return
        }

        currentTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let response = try await fetcher.fetch(normalized)
                try Task.checkCancellation()
                guard self.requestID == activeRequestID else { return }

                self.cache.store(response, for: normalized)
                self.apply(response, for: normalized, clearForward: clearForward)
            } catch is CancellationError {
                return
            } catch {
                guard self.requestID == activeRequestID else { return }

                self.errorMessage = String(describing: error)
                self.items = []
            }

            if self.requestID == activeRequestID {
                self.isLoading = false
            }
        }

        await currentTask?.value
    }

    func goBack() async {
        guard backwardStack.count >= 2 else { return }

        let current = backwardStack.removeLast()
        forwardStack.append(current)
        let previous = backwardStack.removeLast()

        await load(previous, clearForward: false)
    }

    func goForward() async {
        guard let next = forwardStack.popLast() else { return }
        await load(next, clearForward: false)
    }

    private func normalizedSearchLocation(_ location: GopherLocation) -> GopherLocation? {
        let selector = location.selector.removingPercentEncoding ?? location.selector
        if selector.hasPrefix("/search"), selector.contains("\t") == false {
            searchContext = SearchContext(
                host: location.host,
                port: location.port,
                selector: "/search"
            )
            return nil
        }

        searchContext = nil
        return GopherLocation(host: location.host, port: location.port, selector: selector)
    }

    private func apply(_ response: [gopherItem], for location: GopherLocation, clearForward: Bool) {
        items = response
        errorMessage = nil
        currentLocation = location
        findText = ""
        currentFindIndex = 0
        if backwardStack.last != location {
            backwardStack.append(location)
        }
        if clearForward {
            forwardStack.removeAll()
        }
        mergeSidebarItems(response, for: location)
    }

    private func mergeSidebarItems(_ response: [gopherItem], for location: GopherLocation) {
        let childNodes = sidebarChildren(from: response)
        let rootSelector = "/"

        if let index = hosts.firstIndex(where: { $0.host == location.host && $0.port == location.port }) {
            if isRootLocation(location) {
                hosts[index].selector = rootSelector
                hosts[index].message = location.host
                hosts[index].children = childNodes
            } else {
                let title = existingTitle(for: location, in: hosts[index]) ?? sidebarTitle(for: location)
                let page = GopherNode(
                    host: location.host,
                    port: location.port,
                    selector: location.selector,
                    message: title,
                    item: nil,
                    children: childNodes
                )
                hosts[index].children = upserting(page, into: hosts[index].children ?? [])
            }
            return
        }

        let rootChildren: [GopherNode]
        if isRootLocation(location) {
            rootChildren = childNodes
        } else {
            rootChildren = [
                GopherNode(
                    host: location.host,
                    port: location.port,
                    selector: location.selector,
                    message: sidebarTitle(for: location),
                    item: nil,
                    children: childNodes
                )
            ]
        }

        hosts.append(
            GopherNode(
                host: location.host,
                port: location.port,
                selector: rootSelector,
                message: location.host,
                item: nil,
                children: rootChildren
            )
        )
    }

    private func sidebarChildren(from response: [gopherItem]) -> [GopherNode] {
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

        guard nodes.count <= Self.sidebarChildLimit else {
            return []
        }

        var seen = Set<String>()
        return nodes.filter { node in
            let key = "\(node.host):\(node.port):\(normalizedSelector(node.selector))"
            return seen.insert(key).inserted
        }
    }

    private func upserting(_ node: GopherNode, into children: [GopherNode]) -> [GopherNode] {
        var result = children
        if let index = result.firstIndex(where: { matches($0, node) }) {
            result[index] = node
        } else {
            result.append(node)
        }
        return result
    }

    private func existingTitle(for location: GopherLocation, in root: GopherNode) -> String? {
        root.children?.first(where: { child in
            child.host == location.host &&
                child.port == location.port &&
                normalizedSelector(child.selector) == normalizedSelector(location.selector)
        })?.message
    }

    private func isRootLocation(_ location: GopherLocation) -> Bool {
        let selector = normalizedSelector(location.selector)
        return selector == "/" || selector.isEmpty
    }

    private func sidebarTitle(for location: GopherLocation) -> String {
        let selector = normalizedSelector(location.selector)
        if selector == "/" || selector.isEmpty {
            return location.host
        }
        return selector
    }

    private func normalizedSelector(_ selector: String) -> String {
        if selector.isEmpty { return "/" }
        return selector.hasPrefix("/") ? selector : "/\(selector)"
    }

    private func matches(_ lhs: GopherNode, _ rhs: GopherNode) -> Bool {
        lhs.host == rhs.host &&
            lhs.port == rhs.port &&
            normalizedSelector(lhs.selector) == normalizedSelector(rhs.selector)
    }
}

struct SearchContext: Equatable {
    let host: String
    let port: Int
    let selector: String
}
