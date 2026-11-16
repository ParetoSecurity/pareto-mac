//
//  VSCode.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import AppKit
import Combine
import Foundation
import os.log
import OSLog
import Regex
import Version

struct VSCodeUpdateResponse: Decodable {
    let productVersion: String
}

class AppVSCodeCheck: AppCheck {
    static let sharedInstance = AppVSCodeCheck()

    override var appName: String {
        "Visual Studio Code"
    }

    override var appMarketingName: String {
        "Visual Studio Code"
    }

    override var appBundle: String {
        "com.microsoft.VSCode"
    }

    override var UUID: String {
        "febd20fb-3dec-5834-a0ba-58f3342df58c"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://update.code.visualstudio.com/api/update/darwin-universal/stable/latest")
        os_log("Requesting %{public}s", url)

        Network.session.request(url).validate().responseDecodable(of: VSCodeUpdateResponse.self, queue: AppCheck.queue, completionHandler: { response in
            if let value = response.value, response.error == nil {
                os_log("%{public}s version=%{public}s", self.appBundle, value.productVersion)
                completion(value.productVersion)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }
        })
    }
}
