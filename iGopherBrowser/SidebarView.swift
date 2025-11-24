//
//  SidebarView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/13/23.
//

import Foundation
import SwiftUI

struct SidebarView: View {
    let hosts: [GopherNode]
    var onSelect: (GopherNode) -> Void

    @AppStorage("crtMode") var crtMode: Bool = false
    @AppStorage("crtPhosphorColor") var crtPhosphorColorRaw: String = CRTPhosphorColor.green.rawValue

    private var phosphorColor: Color {
        (CRTPhosphorColor(rawValue: crtPhosphorColorRaw) ?? .green).color
    }

    private var textColor: Color {
        crtMode ? phosphorColor : .primary
    }

    var body: some View {
        VStack {
            List(hosts, children: \.children) { node in
                Text(node.message ?? node.host)
                    .foregroundStyle(textColor)
                    .shadow(color: crtMode ? textColor.opacity(0.5) : .clear, radius: crtMode ? 2 : 0)
                    .onTapGesture {
                        onSelect(node)
                    }
            }
            .scrollContentBackground(crtMode ? .hidden : .automatic)
        }
        .navigationTitle("Your Gophertree")
    }
}
