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

    func testWelcomeViewShow() throws {
        _ = WelcomeView()
    }

    func testIntroViewShow() throws {
        _ = IntroView(step: $step)
    }

    func testPermissionsViewShow() throws {
        _ = PermissionsView(step: $step)
    }

    func testChecksViewShow() throws {
        _ = ChecksView(step: $step)
    }

    func testEndViewShow() throws {
        _ = EndView()
    }
}
