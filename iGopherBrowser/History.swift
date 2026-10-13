//
//  History.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/12/23.
//

import Foundation
import SwiftData

@Model
final class HistoryItem {
    var id: UUID
    var title: String
    var host: String
    var port: Int
    var selector: String
    var visitedAt: Date

    init(title: String, host: String, port: Int, selector: String) {
        self.id = UUID()
        self.title = title
        self.host = host
        self.port = port
        self.selector = selector
        self.visitedAt = Date()
    }

    /// Input is ordered newest first; keep the latest visit to each page.
    static func recentUniqueVisits(from visits: [HistoryItem], limit: Int) -> [HistoryItem] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        var result: [HistoryItem] = []
        for visit in visits {
            guard seen.insert(visit.urlString).inserted else { continue }
            result.append(visit)
            if result.count == limit { break }
        }
        return result
    }

    var urlString: String {
        "\(host):\(port)\(selector)"
    }
}
