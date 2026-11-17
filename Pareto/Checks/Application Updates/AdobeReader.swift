//
//  AdobeReader.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import Foundation
import os.log
import OSLog
import Version

class AdobeReaderCheck: AppCheck {
    static let sharedInstance = AdobeReaderCheck()

    override var appName: String {
        "Adobe Acrobat Reader DC"
    }

    override var appMarketingName: String {
        "Adobe Reader"
    }

    override var appBundle: String {
        "com.adobe.Reader"
    }

    override var UUID: String {
        "5c6cdb30-2e84-55b0-9d8e-754067b5094e"
    }

    static func latestVersion(fromManifest response: String) -> String {
        let version = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let isVersion = !version.isEmpty && version.allSatisfy { $0.isNumber || $0 == "." }
        return isVersion ? version : "0.0.0"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        // The Adobe updater (ARM) uses this manifest.
        let url = "https://armmf.adobe.com/arm-manifests/mac/AcrobatDC/reader/current_version.txt"
        os_log("Requesting %{public}s", url)
        Network.session.request(url).validate().responseString(queue: AppCheck.queue, completionHandler: { response in
            if let value = response.value, response.error == nil {
                completion(Self.latestVersion(fromManifest: value))
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }
        })
    }
}
