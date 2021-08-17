//
//  CheckIntegrationTest.swift
//  CheckIntegrationTest
//
//  Created by Janez Troha on 12/08/2021.
//

@testable import Pareto_Security
import XCTest

class CheckIntegrationTest: XCTestCase {
    override class func setUp() {
        super.setUp()
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }

}
