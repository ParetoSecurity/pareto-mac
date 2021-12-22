//
//  WelcomeView.swift
//  WelcomeView
//
//  Created by Janez Troha on 09/09/2021.
//

import Defaults
import SwiftUI

enum Steps {
    case Welcome
    case Permissions
    case Follow
    case Checks
    case End
}

struct WelcomeView: View {
    @State var step = Steps.Welcome

    var body: some View {
        Group {
            switch step {
            case Steps.Welcome:
                IntroView(step: $step)
            case Steps.Permissions:
                PermissionsView(step: $step)
            case Steps.Checks:
                ChecksView(step: $step)
            case Steps.Follow:
                FollowView(step: $step)
            case Steps.End:
                EndView()
            }
        }.onAppear {
            step = Steps.Welcome
        }
    }
}
