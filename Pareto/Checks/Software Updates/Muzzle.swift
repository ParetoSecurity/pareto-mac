//
//  Muzzle.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppMuzzleCheck: AppCheck {
    static let sharedInstance = AppMuzzleCheck()

    override var appName: String { "Muzzle" }
    override var appMarketingName: String { "Muzzle" }
    override var appBundle: String { "com.incident57.Muzzle" }
    override var sparkleURL: String { "https://muzzleapp.com/api/1/appcast.xml" }

    override var UUID: String {
        "99d8f8cd-6522-586c-afbb-c13d824d05a0"
    }
}
