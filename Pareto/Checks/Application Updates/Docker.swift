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

class AppDockerCheck: AppCheck {
    static let sharedInstance = AppDockerCheck()

    override var appName: String {
        "Docker"
    }

    override var appMarketingName: String {
        "Docker"
    }

    override var appBundle: String {
        "com.docker.docker"
    }

    override var sparkleURL: String {
        "https://desktop.docker.com/mac/main/arm64/appcast.xml"
    }

    override var UUID: String {
        "ee11fe36-a372-5cba-a1b4-151748fc2fa7"
    }
}
