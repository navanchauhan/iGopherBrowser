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

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Enter your query")
            TextField("Search", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onSubmit {
                    onSearch(searchText)
                }
            HStack {

                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .padding()

                Button("Search") {
                    onSearch(searchText)
                }
                .keyboardShortcut(.return, modifiers: [])
                .padding()
            }
        }
        .padding()
        #if os(macOS)
        .background(EscapeKeyCapture {
            presentationMode.wrappedValue.dismiss()
        })
        .onExitCommand {
            presentationMode.wrappedValue.dismiss()
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
