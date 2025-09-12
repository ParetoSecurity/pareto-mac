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
    case running = "IconGrayActive"
    case warning = "IconOrange"
    case allOk = "IconGreen"
}

@MainActor
class StatusBarModel: ObservableObject {
    // Default to a known-good asset with vector variants
    @Published var state = StatusBarState.idle {
        didSet {
            // Cancel any pending reset when state changes
            idleResetTask?.cancel()

            // If we just entered allOk, schedule a reset to idle after 30 seconds
            if state == .allOk {
                idleResetTask = Task { [weak self] in
                    // Sleep for 30 seconds
                    try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)

                    // If still allOk after the delay, transition to idle
                    if let self, !Task.isCancelled, self.state == .allOk {
                        self.state = .idle
                    }
                }
            }
        }
    }

    @Published var isRunning = false
    // Bump to force menu refresh re-render when checks finish
    @Published var refreshNonce: Int = 0

    // Keep track of any pending reset task so we can cancel it if the state changes
    private var idleResetTask: Task<Void, Never>?
}

struct StatusBarIcon: View {
    @ObservedObject var statusBarModel: StatusBarModel

    var body: some View {
        if statusBarModel.isRunning {
            Image(StatusBarState.running.rawValue)
                .resizable() // allow downscaling
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                // Center the image within any available space
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .id(statusBarModel.refreshNonce ^ (statusBarModel.isRunning ? 1 : 0))
            // When the user clicks the menu bar icon, if we're currently idle,
            // restore the latest computed state (green/orange) unless snoozed.
        } else {
            Image(statusBarModel.state.rawValue)
                .resizable() // allow downscaling
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                // Center the image within any available space
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .id(statusBarModel.refreshNonce ^ (statusBarModel.isRunning ? 1 : 0))
            // When the user clicks the menu bar icon, if we're currently idle,
            // restore the latest computed state (green/orange) unless snoozed.
        }
    }
}
