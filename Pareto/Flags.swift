//
//  Flags.swift
//  Flags
//
//  Created by Janez Troha on 14/09/2021.
//

import Combine
import Foundation
import os.log

class FlagsUpdater: ObservableObject {
    @Published var personalLicenseSharing: Bool = true
    @Published var teamAPI: Bool = true
    @Published var slowerTeamUpdate: Bool = false
    @Published var nagScreenDelayDays: Int = 7

    func update() {
        struct DNSResponse: Codable {
            let status: Int

            struct Answer: Codable {
                let data: String
            }

            let answer: [Answer]

            enum CodingKeys: String, CodingKey {
                case status = "Status"
                case answer = "Answer"
            }
        }

        do {
            let url = URL(string: "https://dns.google/resolve?name=flags.paretosecurity.com&type=txt")!
            let data = try Data(contentsOf: url)
            let flags = try JSONDecoder().decode(DNSResponse.self, from: data).answer.first?.data
            for flag in flags!.components(separatedBy: ",") {
                let kv = flag.components(separatedBy: "=")
                os_log("Flag: \(kv)")
                switch kv[0] {
                case "personalLicenseSharing":
                    personalLicenseSharing = (kv[1] as NSString).boolValue
                case "teamAPI":
                    teamAPI = (kv[1] as NSString).boolValue
                case "slowerTeamUpdate":
                    slowerTeamUpdate = (kv[1] as NSString).boolValue
                case "nagScreenDelayDays":
                    nagScreenDelayDays = (kv[1] as NSString).integerValue
                default:
                    os_log("Unknwon flag: \(kv[0])")
                }
            }
        } catch {
            os_log("Flags cannot be updated")
        }
    }
}
