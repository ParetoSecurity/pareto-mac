//
//  Flags.swift
//  Flags
//
//  Created by Janez Troha on 14/09/2021.
//

import Alamofire
import Combine
import Foundation
import os.log

class FlagsUpdater: ObservableObject {
    @Published var personalLicenseSharing: Bool = true
    @Published var dashboardMenu: Bool = true
    @Published var dashboardMenuAll: Bool = true
    @Published var teamAPI: Bool = true
    @Published var slowerTeamUpdate: Bool = false
    @Published var nagScreenDelayDays: Int = 7
    @Published var setappUpdate: Int = 4

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

        let url = "https://cloudflare-dns.com/dns-query?name=flags.paretosecurity.com&type=txt"
        let headers: HTTPHeaders = [
            "accept": "application/dns-json"
        ]
        AF.request(url, headers: headers).responseDecodable(of: DNSResponse.self, queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let flags = response.value?.answer.first?.data.replacingOccurrences(of: "\"", with: "") ?? ""
                for flag in flags.components(separatedBy: ",") {
                    let KeyValue = flag.components(separatedBy: "=")
                    os_log("Flag: \(KeyValue)")
                    switch KeyValue[0] {
                    case "personalLicenseSharing":
                        self.personalLicenseSharing = (KeyValue[1] as NSString).boolValue
                    case "teamAPI":
                        self.teamAPI = (KeyValue[1] as NSString).boolValue
                    case "slowerTeamUpdate":
                        self.slowerTeamUpdate = (KeyValue[1] as NSString).boolValue
                    case "nagScreenDelayDays":
                        self.nagScreenDelayDays = (KeyValue[1] as NSString).integerValue
                    case "dashboardMenuAll":
                        self.dashboardMenuAll = (KeyValue[1] as NSString).boolValue
                    case "dashboardMenu":
                        self.dashboardMenu = (KeyValue[1] as NSString).boolValue
                    case "setappUpdate":
                        self.setappUpdate = (KeyValue[1] as NSString).integerValue
                    default:
                        os_log("Unknown flag: \(KeyValue[0])")
                    }
                }
            } else {
                os_log("Unknown flags error: \(response.error.debugDescription)")
            }
        })
    }
}
