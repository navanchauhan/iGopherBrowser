//
//  SearchInputView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//

import SwiftUI

struct SearchInputView: View {

    var host: String
    var port: Int
    var selector: String
    @Binding var searchText: String
    var onSearch: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Enter your query")
            TextField("Search", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityIdentifier("search-query-field")
                .padding()
                .onSubmit {
                    onSearch(searchText)
                }
            HStack {

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .padding()
                .accessibilityIdentifier("search-cancel-button")

                Button("Search") {
                    onSearch(searchText)
                }
                .keyboardShortcut(.return, modifiers: [])
                .padding()
                .accessibilityIdentifier("search-submit-button")
            }
        }
        .padding()
        #if os(macOS) && !canImport(CAdwaita)
        .background(EscapeKeyCapture {
            dismiss()
        })
        .onExitCommand {
            dismiss()
        }
        #endif
    }
}

#if os(macOS)
import AppKit

private struct EscapeKeyCapture: NSViewRepresentable {
    var onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEscape: onEscape)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        private(set) var monitor: Any?
        let onEscape: () -> Void

        init(onEscape: @escaping () -> Void) {
            self.onEscape = onEscape
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // Escape key
                    self.onEscape()
                    return nil
                }
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            removeMonitor()
        }
    }
}
#endif
