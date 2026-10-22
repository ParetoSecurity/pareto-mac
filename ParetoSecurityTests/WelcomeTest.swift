//
//  WelcomeTest.swift
//  WelcomeTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import SwiftUI
import ViewInspector
import XCTest

class WelcomeTest: XCTestCase {
    @State var step = Steps.Welcome

    func testWelcomeViewShow() {
        _ = WelcomeView()
    }

    func testIntroViewShow() {
        _ = IntroView(step: $step)
    }

    func testPermissionsViewShow() {
        _ = PermissionsView(step: $step)
    }

    func testChecksViewShow() {
        _ = ChecksView(step: $step)
    }

    func testEndViewShow() {
        _ = EndView()
    }
}
