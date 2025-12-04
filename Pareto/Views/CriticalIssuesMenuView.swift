//
//  CriticalIssuesMenuView.swift
//  Pareto Security
//
//  Created by Claude on 04/12/2025.
//

import Defaults
import SwiftUI

struct CriticalIssuesMenuView: View {
    @ObservedObject private var failureStore = HTTPFailureStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if failureStore.hasFailures {
            Button {
                openWindow(id: AppWindowID.networkIssues)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.palette)
                        .font(.system(size: 15))
                        .foregroundStyle(.red)
                    Text("Cannot communicate with cloud")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }
}
