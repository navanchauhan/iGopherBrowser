//
//  Bookmark.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID
    var title: String
    var host: String
    var port: Int
    var selector: String
    var dateAdded: Date

    init(title: String, host: String, port: Int, selector: String) {
        self.id = UUID()
        self.title = title
        self.host = host
        self.port = port
        self.selector = selector
        self.dateAdded = Date()
    }

    var urlString: String {
        "\(host):\(port)\(selector)"
    }

    var gopherURL: String {
        "gopher://\(host):\(port)\(selector)"
    }
}
