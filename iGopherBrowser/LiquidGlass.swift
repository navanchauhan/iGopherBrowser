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
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self.glassEffect()
        } else {
            self
        }
    }

    @ViewBuilder
    func liquidGlassInteractive() -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self.glassEffect(.regular.interactive())
        } else {
            self
        }
    }

    @ViewBuilder
    func liquidGlassBar() -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: 12))
        } else {
            self.background(Color.gray.opacity(0.2))
                .cornerRadius(12)
        }
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            configuration.label
                .glassEffect(.regular.interactive())
                .opacity(configuration.isPressed ? 0.8 : 1.0)
        } else {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1.0)
        }
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
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                content
            }
        } else {
            content
        }
    }
}
