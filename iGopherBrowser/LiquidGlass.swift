//
//  LiquidGlass.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import SwiftUI

extension View {
    func liquidGlass() -> some View {
        glassEffect()
    }

    func liquidGlassInteractive() -> some View {
        glassEffect(.regular.interactive())
    }

    func liquidGlassBar() -> some View {
        glassEffect(in: .rect(cornerRadius: 12))
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(.regular.interactive())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
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
        GlassEffectContainer(spacing: 8) {
            content
        }
    }
}
