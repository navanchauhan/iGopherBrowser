import SwiftData
import SwiftUI

/// Quick access to saved pages and recent visits on a spacious display.
struct BrowserLibrarySidebar: View {
    @AppStorage("homeURL") private var homeURL = URL(string: "gopher://gopher.navan.dev:70/")!
    @Query(sort: \Bookmark.dateAdded, order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \HistoryItem.visitedAt, order: .reverse) private var history: [HistoryItem]

    @State private var recentVisits: [HistoryItem] = []

    var onSelect: (GopherNode) -> Void

    var body: some View {
        List {
            Section {
                Button {
                    open(host: homeURL.host ?? "gopher.navan.dev", port: homeURL.port ?? 70, selector: homeURL.path)
                } label: {
                    Label("Home", systemImage: "house")
                }
                .accessibilityIdentifier("sidebar-home-button")
            }

            Section("Bookmarks") {
                if bookmarks.isEmpty {
                    Text("Save a page with the bookmark button.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(bookmarks) { bookmark in
                    Button {
                        open(host: bookmark.host, port: bookmark.port, selector: bookmark.selector)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookmark.title)
                                    .foregroundStyle(.primary)
                                Text(bookmark.host)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "bookmark")
                        }
                    }
                    .accessibilityIdentifier("sidebar-bookmark-row")
                }
            }

            Section("Recent Visits") {
                if recentVisits.isEmpty {
                    Text("Pages you visit will appear here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(recentVisits) { visit in
                    Button {
                        open(host: visit.host, port: visit.port, selector: visit.selector)
                    } label: {
                        Label {
                            Text(visit.title)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        } icon: {
                            Image(systemName: "clock")
                        }
                    }
                    .accessibilityIdentifier("sidebar-history-row")
                }
            }
        }
        .onChange(of: history, initial: true) { _, visits in
            recentVisits = HistoryItem.recentUniqueVisits(from: visits, limit: 10)
        }
        .listStyle(.sidebar)
        .navigationTitle("Library")
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
    }

    private func open(host: String, port: Int, selector: String) {
        onSelect(GopherNode(host: host, port: port, selector: selector, item: nil))
    }
}
