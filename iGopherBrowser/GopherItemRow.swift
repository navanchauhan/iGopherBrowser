//
//  GopherItemRow.swift
//  iGopherBrowser
//

import GopherHelpers
import SwiftUI

struct GopherItemRow: View {
    let item: gopherItem
    let linkColor: Color
    let textColor: Color
    let crtMode: Bool
    let openDirectory: (gopherItem) -> Void
    let openSearch: (gopherItem) -> Void
    let openExternalURL: (URL) -> Void
    let openUnknown: (gopherItem) -> Void

    var body: some View {
        switch item.parsedItemType {
        case .info:
            Text(item.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(textColor)
                .shadow(color: crtMode ? textColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                .frame(height: 20)
                .listRowSeparator(.hidden)
                .padding(.vertical, -8)
                .accessibilityIdentifier("gopher-info-row")
        case .directory:
            rowButton(systemImage: "folder", title: item.message) {
                openDirectory(item)
            }
            .accessibilityIdentifier("gopher-directory-row")
        case .search:
            rowButton(systemImage: "magnifyingglass", title: item.message) {
                openSearch(item)
            }
            .accessibilityIdentifier("gopher-search-row")
        case .text:
            NavigationLink(destination: FileView(item: item)) {
                rowLabel(systemImage: "doc.plaintext", title: item.message)
            }
            .accessibilityIdentifier("gopher-text-row")
        default:
            if item.selector.hasPrefix("URL:"),
               let url = URL(string: item.selector.replacingOccurrences(of: "URL:", with: "")) {
                rowButton(systemImage: "link", title: item.message) {
                    openExternalURL(url)
                }
                .accessibilityIdentifier("gopher-external-link-row")
            } else if [.doc, .image, .gif, .movie, .sound, .bitmap, .binary].contains(item.parsedItemType) {
                NavigationLink(destination: FileView(item: item)) {
                    rowLabel(systemImage: itemToImageType(item), title: item.message)
                }
                .accessibilityIdentifier("gopher-file-row")
            } else {
                rowButton(systemImage: "questionmark.app.dashed", title: item.message) {
                    openUnknown(item)
                }
                .accessibilityIdentifier("gopher-unknown-row")
            }
        }
    }

    private func rowButton(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(systemImage: systemImage, title: title)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(systemImage: String, title: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(title)
            Spacer()
        }
        .contentShape(Rectangle())
        .foregroundStyle(linkColor)
        .shadow(color: crtMode ? linkColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
        .accessibilityElement(children: .combine)
    }
}
