//
//  Flags.swift
//  Flags
//
//  Created by Janez Troha on 14/09/2021.
//

import Combine
import Foundation
import os.log

private struct DNSResponse: Codable {
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

class FlagsUpdater: ObservableObject {
    @Published var personalLicenseSharing: Bool = false
    @Published var teamAPI: Bool = false

    func update() {
        do {
            let url = URL(string: "https://dns.google/resolve?name=flags.paretosecurity.app&type=txt")!
            let data = try Data(contentsOf: url)
            let flags = try JSONDecoder().decode(DNSResponse.self, from: data).answer.first?.data
            for flag in flags!.split(separator: ",") {
                let kv = flag.split(separator: "=")
                os_log("Flag: \(kv)")
                switch kv[0] {
                case "personalLicenseSharing":
                    personalLicenseSharing = (kv[1] as NSString).boolValue
                default:
                    os_log("Unknwon flag: \(kv[0])")
                }
            }
        } catch {
            os_log("Flags cannot be updated")
        }
    }
}
