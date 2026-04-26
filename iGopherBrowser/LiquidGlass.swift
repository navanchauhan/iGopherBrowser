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
            glassEffect()
        #endif
    }

    @ViewBuilder
    func liquidGlassInteractive() -> some View {
        #if os(visionOS)
            self
        #else
            glassEffect(.regular.interactive())
        #endif
    }

    @ViewBuilder
    func liquidGlassBar() -> some View {
        #if os(visionOS)
            self
        #else
            glassEffect(in: .rect(cornerRadius: 12))
        #endif
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        #if os(visionOS)
            configuration.label
                .opacity(configuration.isPressed ? 0.8 : 1.0)
        #else
            configuration.label
                .glassEffect(.regular.interactive())
                .opacity(configuration.isPressed ? 0.8 : 1.0)
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

    @ViewBuilder
    var body: some View {
        #if os(visionOS)
            content
        #else
            GlassEffectContainer(spacing: 8) {
                content
            }
        #endif
    }
}
