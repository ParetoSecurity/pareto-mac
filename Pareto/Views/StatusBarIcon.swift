//
//  StatusBarIcon.swift
//  Pareto Security
//
//  Created by Janez Troha on 20/12/2021.
//

import AppKit
import Defaults
import SwiftUI

enum StatusBarState: String {
    case initial = "Icon"
    case idle = "IconGray"
    case warning = "IconOrange"
    case allOk = "IconGreen"
}

class StatusBarModel: ObservableObject {
    // Default to a known-good asset with vector variants
    @Published var state = StatusBarState.idle
    @Published var isRunning = false
    // Bump to force menu refresh re-render when checks finish
    @Published var refreshNonce: Int = 0
}

struct StatusBarIcon: View {
    @ObservedObject var statusBarModel: StatusBarModel
    

    var body: some View {
        Image(statusBarModel.state.rawValue)
            .resizable() // allow downscaling
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
        .id(statusBarModel.refreshNonce ^ (statusBarModel.isRunning ? 1 : 0))
    }
}
