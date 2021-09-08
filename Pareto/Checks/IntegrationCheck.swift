//
//  IntegrationCheck.swift
//  IntegrationCheck
//
//  Created by Janez Troha on 12/08/2021.
//

import Foundation
import os.log

class IntegrationCheck: ParetoCheck {
    override var UUID: String {
        "aaaaaaaa-bbbb-cccc-dddd-abcdef123456"
    }

    override var TitleON: String {
        "Unit test mock ON"
    }

    override var TitleOFF: String {
        "Unit test mock OFF"
    }

    override func checkPasses() -> Bool {
        return true
    }
}
