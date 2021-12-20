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
}

struct StatusBarIcon: View {
    @ObservedObject var statusBarModel: StatusBarModel

    var body: some View {
        ZStack {
            // Moves in from leading out, out to trailing edge.
            Image(statusBarModel.state.rawValue)
                .resizable()
                .frame(width: 22, height: 20, alignment: .center)

        }.frame(width: 22, height: 20, alignment: .center).padding(.horizontal, 2)
            .padding(.vertical, 2)
    }
}

struct StatusBarIcon_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarIcon(statusBarModel: StatusBarModel())
    }
}
