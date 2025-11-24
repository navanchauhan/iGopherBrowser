//
//  BookmarksView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 2/7/24.
//

import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Bookmark.dateAdded, order: .reverse) private var bookmarks: [Bookmark]

    var onSelectBookmark: ((String, Int, String) -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Bookmarks you add will appear here.")
                    )
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            Button {
                                onSelectBookmark?(bookmark.host, bookmark.port, bookmark.selector)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(bookmark.urlString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
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
        .frame(minWidth: 350, minHeight: 400)
        #endif
    }

    private func deleteBookmarks(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bookmarks[index])
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
                Section {
                    TextField("Title", text: $title)
                } header: {
                    Text("Bookmark Name")
                }

                Section {
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
    BookmarksView()
        .modelContainer(for: Bookmark.self, inMemory: true)
}
