//
//  LibreOffice.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppLibreOfficeCheck: ParetoCheck {
    static let sharedInstance = AppLibreOfficeCheck()

    override var UUID: String {
        "f22122ad-6219-5fff-b5e6-ef15a00231f3"
    }

    override var TitleON: String {
        "LibreOffice is up-to-date"
    }

    override var TitleOFF: String {
        "LibreOffice has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "LibreOffice") >= ""
    }
}
