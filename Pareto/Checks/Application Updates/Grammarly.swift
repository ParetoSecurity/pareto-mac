//
//  Grammarly.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2022.
//
import Alamofire
import os.log
import Regex
class AppGrammarlyCheck: AppCheck {
    static let sharedInstance = AppGrammarlyCheck()

    override var appName: String { "Grammarly Desktop" }
    override var appMarketingName: String { "Grammarly" }
    override var appBundle: String { "com.grammarly.ProjectLlama" }
    override var sparkleURL: String { "https://download-mac.grammarly.com/appcast.xml" }

    override var UUID: String {
        "be6e677f-231a-431c-9c80-861c867b8920"
    }
}
