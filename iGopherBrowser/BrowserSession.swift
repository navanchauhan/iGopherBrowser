//
//  BrowserSession.swift
//  iGopherBrowser
//

import Foundation
import GopherHelpers
import Observation

@MainActor
@Observable
final class BrowserSession {
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

    @ObservationIgnored private let fetcher: any GopherFetching
    @ObservationIgnored private let cache: any GopherResponseCaching
    @ObservationIgnored private var currentTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

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
        var node = GopherNode(
            host: location.host,
            port: location.port,
            selector: location.selector,
            item: nil,
            children: response.compactMap { item in
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
        )

        if let index = hosts.firstIndex(where: { $0.host == location.host && $0.port == location.port }) {
            hosts[index].children = hosts[index].children?.map { child in
                if child.selector == location.selector {
                    node.message = child.message
                    return node
                }
                return child
            }
        } else {
            node.selector = "/"
            hosts.append(node)
        }
    }
}

struct SearchContext: Equatable {
    let host: String
    let port: Int
    let selector: String
}
