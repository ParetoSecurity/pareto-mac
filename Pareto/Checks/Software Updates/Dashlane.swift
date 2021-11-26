//
//  Dashlane.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppDashlaneCheck: AppCheck {
    static let sharedInstance = AppDashlaneCheck()

    override var appName: String { "Dashlane" }
    override var appMarketingName: String { "Dashlane" }
    override var appBundle: String { "com.dashlane.dashlanephonefinal" }
    override var sparkleURL: String { "" }

    override var UUID: String {
        "4cb5ec2d-b3c5-5f72-bed1-aae0c26201b9"
    }

    override var TitleON: String {
        "Dashlane is up-to-date"
    }

    override var TitleOFF: String {
        "Dashlane has an available update"
    }
}
