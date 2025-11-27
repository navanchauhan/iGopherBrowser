//
//  BookmarksView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 2/7/24.
//

import SwiftUI
import SwiftData

struct BookmarksHistoryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case bookmarks = "Bookmarks"
        case history = "History"
        var id: Self { self }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Bookmark.dateAdded, order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \HistoryItem.visitedAt, order: .reverse) private var historyItems: [HistoryItem]

    @State private var selectedSection: Section = .bookmarks

    var onSelectItem: ((String, Int, String) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedSection) {
                    ForEach(Section.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Group {
                    switch selectedSection {
                    case .bookmarks:
                        bookmarksList
                    case .history:
                        historyList
                    }
                }
            }
            .navigationTitle(selectedSection.rawValue)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedSection == .bookmarks {
                        EditButton()
                    } else {
                        Button("Clear") {
                            clearHistory()
                        }
                        .disabled(historyItems.isEmpty)
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
    }

    @ViewBuilder
    private var bookmarksList: some View {
        if bookmarks.isEmpty {
            ContentUnavailableView(
                "No Bookmarks",
                systemImage: "bookmark",
                description: Text("Tap the bookmark icon to save pages.")
            )
        } else {
            List {
                ForEach(bookmarks) { bookmark in
                    Button {
                        onSelectItem?(bookmark.host, bookmark.port, bookmark.selector)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bookmark.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(bookmark.urlString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteBookmarks)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var historyList: some View {
        if historyItems.isEmpty {
            ContentUnavailableView(
                "No History",
                systemImage: "clock",
                description: Text("Pages you visit will appear here.")
            )
        } else {
            List {
                ForEach(groupedHistory, id: \.0) { date, items in
                    SwiftUI.Section(header: Text(formatDateHeader(date))) {
                        ForEach(items) { item in
                            Button {
                                onSelectItem?(item.host, item.port, item.selector)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    HStack {
                                        Text(item.urlString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(formatTime(item.visitedAt))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            deleteHistoryItems(items: items, at: indexSet)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var groupedHistory: [(Date, [HistoryItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: historyItems) { item in
            calendar.startOfDay(for: item.visitedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func deleteBookmarks(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bookmarks[index])
        }
    }

    private func deleteHistoryItems(items: [HistoryItem], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private func clearHistory() {
        for item in historyItems {
            modelContext.delete(item)
        }
    }
}

struct AddBookmarkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let host: String
    let port: Int
    let selector: String

    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    TextField("Title", text: $title)
                } header: {
                    Text("Bookmark Name")
                }

                SwiftUI.Section {
                    LabeledContent("Host", value: host)
                    LabeledContent("Port", value: "\(port)")
                    LabeledContent("Selector", value: selector.isEmpty ? "/" : selector)
                } header: {
                    Text("Location")
                }
            }
            .navigationTitle("Add Bookmark")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBookmark()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            if title.isEmpty {
                title = "\(host)\(selector)"
            }
        }
        #if os(macOS)
        .frame(minWidth: 350, minHeight: 250)
        #endif
    }

    private func saveBookmark() {
        let bookmark = Bookmark(
            title: title,
            host: host,
            port: port,
            selector: selector
        )
        modelContext.insert(bookmark)
        dismiss()
    }
}

#Preview {
    BookmarksHistoryView()
        .modelContainer(for: [Bookmark.self, HistoryItem.self], inMemory: true)
}
