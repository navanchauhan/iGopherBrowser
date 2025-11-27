//
//  CRTEffect.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI

// MARK: - CRT Phosphor Color Options

enum CRTPhosphorColor: String, CaseIterable, Identifiable {
    case green = "green"
    case amber = "amber"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .green: return "P1 Green"
        case .amber: return "P3 Amber"
        }
    }

    var color: Color {
        switch self {
        case .green: return Color(red: 0.2, green: 1.0, blue: 0.4)
        case .amber: return Color(red: 1.0, green: 0.7, blue: 0.2)
        }
    }
}

// MARK: - CRT Color Theme

struct CRTTheme {
    static let phosphorGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    static let phosphorAmber = Color(red: 1.0, green: 0.7, blue: 0.2)
    static let screenBackground = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let scanlineColor = Color.black.opacity(0.3)
    static let glowColor = Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.15)

    static func phosphorColor(for type: CRTPhosphorColor) -> Color {
        type.color
    }
}

// MARK: - Scanline Overlay

struct ScanlineOverlay: View {
    let lineSpacing: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: lineSpacing) {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(CRTTheme.scanlineColor))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - CRT Vignette Effect

struct CRTVignette: View {
    var body: some View {
        GeometryReader { geometry in
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.7)
                ]),
                center: .center,
                startRadius: min(geometry.size.width, geometry.size.height) * 0.3,
                endRadius: max(geometry.size.width, geometry.size.height) * 0.8
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - CRT Screen Curvature

struct CRTCurvature: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.5),
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            )
            .shadow(color: CRTTheme.phosphorGreen.opacity(0.3), radius: 20)
    }
}

// MARK: - CRT Text Style

struct CRTTextStyle: ViewModifier {
    let color: Color

    init(color: Color = CRTTheme.phosphorGreen) {
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.8), radius: 1)
            .shadow(color: color.opacity(0.5), radius: 3)
    }
}

// MARK: - Full CRT Effect Modifier

struct CRTEffectModifier: ViewModifier {
    @AppStorage("crtScanlines") var showScanlines: Bool = true
    @AppStorage("crtVignette") var showVignette: Bool = true

    func body(content: Content) -> some View {
        content
            .background(CRTTheme.screenBackground)
            .overlay {
                if showScanlines {
                    ScanlineOverlay()
                }
            }
            .overlay {
                if showVignette {
                    CRTVignette()
                }
            }
    }
}

// MARK: - CRT Container View

struct CRTContainer<Content: View>: View {
    @AppStorage("crtMode") var crtMode: Bool = false
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if crtMode {
            content
                .modifier(CRTEffectModifier())
                .environment(\.colorScheme, .dark)
        } else {
            content
        }
    }
}

// MARK: - View Extensions

extension View {
    func crtEffect(enabled: Bool = true) -> some View {
        modifier(CRTEffectModifier())
            .opacity(enabled ? 1 : 0)
    }

    func crtTextStyle(color: Color = CRTTheme.phosphorGreen) -> some View {
        modifier(CRTTextStyle(color: color))
    }

    func crtScreen() -> some View {
        modifier(CRTCurvature())
    }
}

// MARK: - CRT Mode Environment Key

struct CRTModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var crtMode: Bool {
        get { self[CRTModeKey.self] }
        set { self[CRTModeKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview("CRT Effect") {
    VStack(spacing: 20) {
        Text("GOPHER://NAVAN.DEV")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .crtTextStyle()

        Text("Welcome to the Gopher Network")
            .font(.system(size: 14, design: .monospaced))
            .crtTextStyle()

        HStack {
            Image(systemName: "folder")
            Text("Documents")
        }
        .font(.system(size: 12, design: .monospaced))
        .crtTextStyle()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .modifier(CRTEffectModifier())
}
