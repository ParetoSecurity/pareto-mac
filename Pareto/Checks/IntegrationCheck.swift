//
//  IntegrationCheck.swift
//  IntegrationCheck
//
//  Created by Janez Troha on 12/08/2021.
//

import Foundation
import os.log

class IntegrationCheck: ParetoCheck {
    final var ID = "aaaaaaaa-bbbb-cccc-dddd-abcdef123456"
    final var TITLE = "Unit test mock"

    required init(id _: String! = "", title _: String! = "") {
        super.init(id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        return true
    }
}
