//
//  WhatsNew.swift
//  iGopherBrowser
//
//  Created by ChatGPT on 11/27/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Central configuration for "What's New" content.
struct WhatsNewConfig {
    /// Bump this identifier whenever a new round of features should be shown.
    static let currentVersion = "2025.11-crt-mode"

    static let title = "What's New"
    static let subtitle =
        "Relive the glow of vintage terminals with the brand-new CRT Display Mode."
}

/// Describes a single entry in the What's New list.
struct WhatsNewFeature: Identifiable {
    let id: String
    let title: String
    let message: String
    let iconSystemName: String
    let accessory: AnyView?

    init(
        id: String,
        title: String,
        message: String,
        iconSystemName: String,
        accessory: AnyView? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.iconSystemName = iconSystemName
        self.accessory = accessory
    }
}

struct WhatsNewView: View {
    let features: [WhatsNewFeature]
    let dismissTitle: String
    let onPrimaryAction: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            content
                .padding(containerOuterPadding)
        }
        #if os(iOS)
            .presentationDetents([.medium, .large])
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(WhatsNewConfig.title)
                    .font(.largeTitle.weight(.bold))
                Text(WhatsNewConfig.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(features) { feature in
                        featureRow(feature)
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                onPrimaryAction?()
                onDismiss()
            } label: {
                Text(dismissTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, continueButtonVerticalPadding)
            }
            #if os(macOS)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            #else
                .buttonStyle(.glassProminent)
            #endif
        }
            .padding(containerInnerPadding)
        .frame(maxWidth: containerWidth)
        .background(containerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(containerShadowOpacity), radius: 30, y: 18)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Later") { onDismiss() }
            }
        }
    }

    @ViewBuilder
    private func featureRow(_ feature: WhatsNewFeature) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: feature.iconSystemName)
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.accentColor)
                    .background {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title)
                        .font(.headline)
                    Text(feature.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if let accessory = feature.accessory {
                accessory
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(featureCardBackground)
        )
    }

    private var featureCardBackground: Color {
        #if os(macOS)
            Color(nsColor: NSColor.windowBackgroundColor)
        #else
            Color(uiColor: .secondarySystemBackground)
        #endif
    }

    private var containerWidth: CGFloat? {
        #if os(macOS)
            520
        #else
            nil
        #endif
    }

    private var containerInnerPadding: CGFloat {
        #if os(macOS)
            32
        #else
            24
        #endif
    }

    private var containerOuterPadding: CGFloat {
        #if os(macOS)
            24
        #else
            0
        #endif
    }

    private var containerBackground: some View {
        #if os(macOS)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: NSColor.windowBackgroundColor),
                            Color(nsColor: NSColor.controlBackgroundColor)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        #else
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
        #endif
    }

    private var containerShadowOpacity: Double {
        #if os(macOS)
            0.35
        #else
            0
        #endif
    }

    private var continueButtonVerticalPadding: CGFloat {
        #if os(macOS)
            10
        #else
            14
        #endif
    }

}
