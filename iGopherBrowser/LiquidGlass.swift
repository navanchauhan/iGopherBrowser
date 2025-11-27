//
//  LiquidGlass.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlass() -> some View {
        #if os(visionOS)
            self
        #else
            if #available(iOS 26.0, macOS 26.0, *) {
                self.glassEffect()
            } else {
                self
            }
        #endif
    }

    @ViewBuilder
    func liquidGlassInteractive() -> some View {
        #if os(visionOS)
            self
        #else
            if #available(iOS 26.0, macOS 26.0, *) {
                self.glassEffect(.regular.interactive())
            } else {
                self
            }
        #endif
    }

    @ViewBuilder
    func liquidGlassBar() -> some View {
        #if os(visionOS)
            self.background(Color.gray.opacity(0.2))
                .cornerRadius(12)
        #else
            if #available(iOS 26.0, macOS 26.0, *) {
                self.glassEffect(in: .rect(cornerRadius: 12))
            } else {
                self.background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
            }
        #endif
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        #if os(visionOS)
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1.0)
        #else
            if #available(iOS 26.0, macOS 26.0, *) {
                configuration.label
                    .glassEffect(.regular.interactive())
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            } else {
                configuration.label
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            }
        #endif
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle()
    }
}

struct LiquidGlassToolbar<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if os(visionOS)
            content
        #else
            if #available(iOS 26.0, macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    content
                }
            } else {
                content
            }
        #endif
    }
}
