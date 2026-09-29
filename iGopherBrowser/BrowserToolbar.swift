//
//  BrowserToolbar.swift
//  iGopherBrowser
//

import SwiftUI

#if os(iOS)
struct iOSToolbarView: View {
    @Binding var url: String
    let shareURL: URL
    let backwardStack: [GopherLocation]
    let forwardStack: [GopherLocation]
    let currentHost: String
    @Binding var showAddBookmark: Bool
    @Binding var showBookmarks: Bool
    @Binding var showPreferences: Bool
    @Binding var showFindInPage: Bool
    let hasContent: Bool
    let onGo: () -> Void
    let onHome: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    @Binding var showHomeTooltip: Bool
    let homeTooltipMessage: String
    let onHomeTooltipAutoDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // URL bar with Go button
            HStack(spacing: 8) {
                TextField("Enter URL", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .textContentType(.URL)
                    .accessibilityIdentifier("url-field")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .glassEffect(in: .rect(cornerRadius: 10))
                    }

                Button(action: onGo) {
                    Text("Go")
                        .fontWeight(.medium)
                }
                .keyboardShortcut(.defaultAction)
                .modifier(GoButtonStyle())
                .accessibilityIdentifier("go-button")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Bottom toolbar - cleaner design
            HStack(spacing: 0) {
                // Navigation group
                HStack(spacing: 4) {
                    navButton(icon: "chevron.left", accessibilityLabel: "Back", identifier: "back-button", action: onBack)
                        .disabled(backwardStack.count < 2)

                    navButton(icon: "chevron.right", accessibilityLabel: "Forward", identifier: "forward-button", action: onForward)
                        .disabled(forwardStack.isEmpty)
                }
                .modifier(ToolbarGroupStyle())

                Spacer()

                // Center actions - Home & Bookmark
                HStack(spacing: 4) {
                    HomeButtonTooltipWrapper(
                        isVisible: $showHomeTooltip,
                        message: homeTooltipMessage,
                        onAutoDismiss: onHomeTooltipAutoDismiss
                    ) {
                        navButton(icon: "house", accessibilityLabel: "Home", identifier: "home-button", action: onHome)
                    }

                    Button(action: { showAddBookmark = true }) {
                        Image(systemName: currentHost.isEmpty ? "bookmark" : "bookmark.fill")
                            .font(.system(size: 18))
                            .frame(width: 44, height: 36)
                    }
                    .disabled(currentHost.isEmpty)
                    .accessibilityLabel("Add Bookmark")
                    .accessibilityIdentifier("add-bookmark-button")
                }
                .modifier(ToolbarGroupStyle())

                Spacer()

                // Right actions group
                HStack(spacing: 4) {
                    navButton(icon: "clock.arrow.circlepath", accessibilityLabel: "Bookmarks and History", identifier: "bookmarks-history-button", action: { showBookmarks = true })

                    Menu {
                        Button(action: { showFindInPage = true }) {
                            Label("Find in Page", systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(!hasContent)
                        .accessibilityIdentifier("find-in-page-button")

                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(action: { showPreferences = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                        .accessibilityIdentifier("settings-button")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .frame(width: 44, height: 36)
                    }
                    .accessibilityIdentifier("browser-menu-button")
                }
                .modifier(ToolbarGroupStyle())
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func navButton(
        icon: String,
        accessibilityLabel: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 44, height: 36)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Button Styles for iOS Toolbar

private struct GoButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.liquidGlass)
    }
}

private struct ToolbarGroupStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(in: .capsule)
    }
}

#endif

#if os(macOS) || os(visionOS)
struct macOSToolbarView: View {
    @Binding var url: String
    var isURLFocused: FocusState<Bool>.Binding
    let shareURL: URL
    let backwardStack: [GopherLocation]
    let forwardStack: [GopherLocation]
    let currentHost: String
    @Binding var showAddBookmark: Bool
    @Binding var showBookmarks: Bool
    @Binding var showPreferences: Bool
    let onGo: () -> Void
    let onHome: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    @Binding var showHomeTooltip: Bool
    let homeTooltipMessage: String
    let onHomeTooltipAutoDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            navigationButtons
            urlField
            actionButtons
            goButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var navigationButtons: some View {
        LiquidGlassToolbar {
            HStack(spacing: 8) {
                HomeButtonTooltipWrapper(
                    isVisible: $showHomeTooltip,
                    message: homeTooltipMessage,
                    onAutoDismiss: onHomeTooltipAutoDismiss
                ) {
                    Button(action: onHome) {
                        Label("Home", systemImage: "house")
                            .labelStyle(.iconOnly)
                    }
                    .liquidGlassInteractive()
                    .keyboardShortcut("r", modifiers: [.command])
                    .accessibilityIdentifier("home-button")
                }

                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }
                .liquidGlassInteractive()
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(backwardStack.count < 2)
                .accessibilityIdentifier("back-button")

                Button(action: onForward) {
                    Label("Forward", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                }
                .liquidGlassInteractive()
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(forwardStack.isEmpty)
                .accessibilityIdentifier("forward-button")
            }
        }
    }

    @ViewBuilder
    private var urlField: some View {
        TextField("Enter a URL", text: $url)
            .focused(isURLFocused)
            .padding(10)
            .liquidGlassBar()
            .accessibilityIdentifier("url-field")
    }

    @ViewBuilder
    private var actionButtons: some View {
        LiquidGlassToolbar {
            HStack(spacing: 8) {
                Button(action: { showAddBookmark = true }) {
                    Label("Add Bookmark", systemImage: "bookmark.fill")
                        .labelStyle(.iconOnly)
                }
                .liquidGlassInteractive()
                .disabled(currentHost.isEmpty)
                .accessibilityIdentifier("add-bookmark-button")

                Button(action: { showBookmarks = true }) {
                    Label("Bookmarks", systemImage: "book")
                        .labelStyle(.iconOnly)
                }
                .liquidGlassInteractive()
                .accessibilityIdentifier("bookmarks-history-button")

                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .liquidGlassInteractive()
            }
        }
    }

    @ViewBuilder
    private var goButton: some View {
        Button("Go", action: onGo)
            .buttonStyle(.liquidGlass)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("go-button")
    }
}
#endif

// MARK: - First Run Tooltip

struct HomeButtonTooltipWrapper<Content: View>: View {
    @Binding var isVisible: Bool
    let message: String
    let onAutoDismiss: () -> Void
    private let content: () -> Content
    @State private var didScheduleDismiss = false

    init(
        isVisible: Binding<Bool>,
        message: String,
        onAutoDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isVisible = isVisible
        self.message = message
        self.onAutoDismiss = onAutoDismiss
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            content()

            if isVisible {
                HomeTooltipCard(message: message)
                    .offset(y: -72)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        scheduleAutoDismiss()
                    }
            }
        }
    }

    private func scheduleAutoDismiss() {
        guard !didScheduleDismiss else { return }
        didScheduleDismiss = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if isVisible {
                withAnimation(.spring()) {
                    isVisible = false
                }
                onAutoDismiss()
            }
        }
    }
}

private struct HomeTooltipCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tip")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tooltipBackground)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
        )
        .frame(maxWidth: 220)
    }

    private var tooltipBackground: Color {
        #if os(macOS)
            Color(nsColor: NSColor.windowBackgroundColor)
        #else
            Color(uiColor: .systemBackground)
        #endif
    }
}
