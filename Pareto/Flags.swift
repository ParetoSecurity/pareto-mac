//
//  Flags.swift
//  Flags
//
//  Created by Janez Troha on 14/09/2021.
//

import Foundation

struct DNSResponse: Codable {
    let status: Int

    struct Answer: Codable {
        let name: String
        let type, ttl: Int
        let data: String
        enum CodingKeys: String, CodingKey {
            case name, type
            case ttl = "TTL"
            case data
        }
    }

    let answer: [Answer]

    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case answer = "Answer"
    }
}

struct Flags: Decodable {
    var personalLicense: Bool = false
}

func getLatestFlags() throws -> String? {
    guard Bundle.main.executableURL != nil else {
        throw Error.bundleExecutableURL
    }
    let url = URL(string: "https://dns.google/resolve?name=flags.paretosecurity.app&type=txt")!
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(DNSResponse.self, from: data).answer.first?.data
}
