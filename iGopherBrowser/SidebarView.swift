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
    
    var body: some View {
        List(hosts, children: \.children) { node in
            Text(node.message ?? node.host)
                .onTapGesture {
                    onSelect(node)
                }
            }
    }
}
