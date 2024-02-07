//
//  BookmarksView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 2/7/24.
//

import SwiftUI

// Bookmarks and History Sheet

struct BookmarksView: View {
    
    enum sectionType: String, CaseIterable, Identifiable {
        case bookmarks, history
        var id: Self {self}
    }
    
    @State private var selectedSection: sectionType = .bookmarks
    
    var body: some View {
        VStack {
            Picker("Section", selection: $selectedSection) {
                ForEach(sectionType.allCases) { section in
                    Text(section.rawValue.capitalized)
                }
            }.pickerStyle(.segmented).padding(.top, 20).padding(.leading, 10).padding(.trailing, 10).padding(.bottom, 10)
            Text("You picked \(selectedSection.rawValue.capitalized)")
            Spacer()
        }
    }
}

#Preview {
    BookmarksView()
}
