//
//  ParetoRelease.swift
//  Pareto Security
//
//  Created by Janez Troha on 4. 3. 25.
//

import Foundation
import Defaults
import Alamofire
import os.log

struct ParetoRelease: Codable {
    let tagName: String
    let targetCommitish: String
    let name: String
    let draft: Bool
    let prerelease: Bool
    let createdAt: Date
    let publishedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case targetCommitish = "target_commitish"
        case name
        case draft
        case prerelease
        case createdAt = "created_at"
        case publishedAt = "published_at"
    }
}

typealias ParetoReleases = [ParetoRelease]

class ParetoUpdated: ParetoCheck {
    static let sharedInstance = ParetoUpdated()
    
    override var UUID: String {
        "44e4754a-0b42-4964-9cc2-b88b2023cb1e"
    }
    
    override var TitleON: String {
        "Pareto Security is up-to-date"
    }
    
    override var TitleOFF: String {
        "Pareto Security is outdated"
    }
    
    private func getPlatform() -> String {
        return "macos"
    }
    
    private func getDistribution() -> String {
        if !Defaults[.teamID].isEmpty {
            return "app-live-team"
        }
        return "app-live-opensource"
    }
    
    private func checkForUpdates(completion: @escaping (Bool) -> Void) {
        let baseURL = "https://paretosecurity.com/api/updates"
        
        let parameters: [String: String] = [
            "uuid": Defaults[.machineUUID],
            "version": AppInfo.appVersion,
            "os_version": AppInfo.macOSVersionString,
            "platform": getPlatform(),
            "app": "auditor",
            "distribution": getDistribution()
        ]
        
        AF.request(baseURL, parameters: parameters)
            .responseDecodable(of: ParetoReleases.self, queue: AppCheck.queue) { response in
                switch response.result {
                case .success(let releases):
                    if releases.isEmpty {
                        os_log("No releases found during update check")
                        completion(false)
                        return
                    }
                    
                    let isUpToDate = releases[0].tagName == AppInfo.appVersion
                    os_log("Update check completed. Current version: %{public}s, Latest version: %{public}s",
                           AppInfo.appVersion,
                           releases[0].tagName)
                    completion(isUpToDate)
                    
                case .failure(let error):
                    os_log("Failed to check for updates: %{public}s", error.localizedDescription)
                    completion(false)
                }
            }
    }
    
    private var updateCheckResult: Bool = false
    private var isCheckingForUpdates: Bool = false
    private let checkLock = DispatchSemaphore(value: 1)
    
    override func checkPasses() -> Bool {
        checkLock.wait()
        defer { checkLock.signal() }
        
        if !isCheckingForUpdates {
            isCheckingForUpdates = true
            
            let checkSemaphore = DispatchSemaphore(value: 0)
            
            checkForUpdates { result in
                self.updateCheckResult = result
                self.isCheckingForUpdates = false
                checkSemaphore.signal()
            }
            
            _ = checkSemaphore.wait(timeout: .now() + 10)
        }
        
        return updateCheckResult
    }
}
