//
//  StatusBarIcon.swift
//  Pareto Security
//
//  Created by Janez Troha on 20/12/2021.
//

import SwiftUI

enum StatusBarState: String {
    case ok = "IconGray"
    case warning = "IconOrange"
}

class StatusBarModel: ObservableObject {
    @Published var state = StatusBarState.ok
    @Published var isRunning = false
}

struct StatusBarIcon: View {
    @ObservedObject var statusBarModel: StatusBarModel
    let imageNames: [String] = [StatusBarState.ok.rawValue, StatusBarState.warning.rawValue]

    var body: some View {
        ZStack {
            // Moves in from leading out, out to trailing edge.
            if statusBarModel.isRunning {
                ZStack {
                    Image(statusBarModel.state.rawValue)
                        .resizable()
                        .blur(radius: 0.8)
                        .frame(width: 22, height: 20, alignment: .center)
                    ProgressView()
                        .frame(width: 5.0, height: 5.0)
                        .blur(radius: 0.8)
                        .scaleEffect(x: 0.5, y: 0.5, anchor: .center)
                }

            } else {
                Image(statusBarModel.state.rawValue)
                    .resizable()
                    .frame(width: 22, height: 20, alignment: .center)
            }

        }.frame(width: 26, height: 20, alignment: .center).padding(.horizontal, 2)
            .padding(.vertical, 2)
    }
}

struct StatusBarIcon_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarIcon(statusBarModel: StatusBarModel())
    }
}
