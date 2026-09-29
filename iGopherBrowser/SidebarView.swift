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

    @CRTAppearance private var crt

    private var textColor: Color {
        crt.text()
    }

    var body: some View {
        VStack {
            List(hosts, children: \.children) { node in
                Button {
                    onSelect(node)
                } label: {
                    Text(node.message ?? node.host)
                        .foregroundStyle(textColor)
                        .crtGlow(crt, color: textColor)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebar-node-row")
            }
            .scrollContentBackground(crt.isEnabled ? .hidden : .automatic)
        }
        .navigationTitle("Your Gophertree")
    }
}
