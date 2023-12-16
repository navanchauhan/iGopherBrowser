//
//  SearchInputView.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//

import SwiftUI

struct SearchInputView: View {
    
    var host: String
    var port: Int
    var selector: String
    @Binding var searchText: String
    var onSearch: (String) -> Void
    
    var body: some View {
        VStack {
            Text("Enter your query")
            TextField("Search", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button("Search") {
                onSearch(searchText)
            }
            .padding()
        }
        .padding()
    }
}
