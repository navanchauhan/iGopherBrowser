//
//  Helpers.swift
//  iGopherBrowser
//
//  Created by Navan Chauhan on 12/16/23.
//

import Foundation
import SwiftGopherClient

public func getHostAndPort(
    from urlString: String, defaultPort: Int = 70, defaultHost: String = "gopher.navan.dev"
) -> (host: String, port: Int, selector: String) {
    let location = GopherLocation(
        urlString,
        defaultPort: defaultPort,
        defaultHost: defaultHost
    )
    return (location.host, location.port, location.selector)
}
