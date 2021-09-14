//
//  Flags.swift
//  Flags
//
//  Created by Janez Troha on 14/09/2021.
//

import Foundation

struct Flags: Decodable {
    var personalLicense: Bool = false
}

func getLatestFlags() throws -> Flags? {
    guard Bundle.main.executableURL != nil else {
        throw Error.bundleExecutableURL
    }
    let url = URL(string: "https://dns.google/resolve?name=flags.paretosecurity.app&type=txt")!
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Flags.self, from: data)
}
