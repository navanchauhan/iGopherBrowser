//
//  FindInPageBar.swift
//  iGopherBrowser
//

import SwiftUI

struct FindInPageBar: View {
    @Binding var findText: String
    @Binding var currentIndex: Int
    let totalMatches: Int
    var isFocused: FocusState<Bool>.Binding
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Find in page", text: $findText)
                    .textFieldStyle(.plain)
                    .focused(isFocused)
                    .accessibilityIdentifier("find-in-page-field")
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif

                if !findText.isEmpty {
                    Text("\(totalMatches > 0 ? currentIndex + 1 : 0)/\(totalMatches)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.2))
            .clipShape(.rect(cornerRadius: 8))

            if !findText.isEmpty {
                Button {
                    if totalMatches > 0 {
                        currentIndex = (currentIndex - 1 + totalMatches) % totalMatches
                    }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(totalMatches == 0)
                .accessibilityIdentifier("find-previous-button")

                Button {
                    if totalMatches > 0 {
                        currentIndex = (currentIndex + 1) % totalMatches
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(totalMatches == 0)
                .accessibilityIdentifier("find-next-button")
            }

            Button("Done", action: onDismiss)
                .fontWeight(.medium)
                .accessibilityIdentifier("find-done-button")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .onAppear {
            isFocused.wrappedValue = true
        }
    }
}
