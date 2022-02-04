//
//  Docker.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import Foundation
import os.log
import OSLog
import Regex
import Version

class AdobeReaderCheck: AppCheck {
    static let sharedInstance = AdobeReaderCheck()

    override var appName: String { "Adobe Acrobat Reader DC" }
    override var appMarketingName: String { "Adobe Reader" }
    override var appBundle: String { "com.adobe.Reader" }

    override var UUID: String {
        "5c6cdb30-2e84-55b0-9d8e-754067b5094e"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://helpx.adobe.com/acrobat/release-note/release-notes-acrobat-reader.html")
        let linksRegex = Regex("<a .+ReleaseNotesDC.+>(.+)</a>")
        let versionRegex = Regex(".+\\((.+)\\)")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.data != nil {
                let links = linksRegex.firstMatch(in: response.value ?? "")
                let result = versionRegex.firstMatch(in: links?.groups.first?.value ?? "DC Sep 2021 (21.007.2009x)")
                completion(result?.groups.first?.value ?? "0.0.0")
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
