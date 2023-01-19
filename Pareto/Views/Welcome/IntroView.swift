//
//  IntroView.swift
//  Pareto Security
//
//  Created by Janez Troha on 09/11/2021.
//

import Defaults
import LaunchAtLogin
import SwiftUI

struct IntroView: View {
    @Binding var step: Steps
    @ObservedObject private var atLogin = LaunchAtLogin.observable
    @Default(.sendCrashReports) var sendCrashReports

    var body: some View {
        VStack {
            VStack {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minHeight: 180, alignment: .center)
                    .accessibility(hidden: true)

                Text("Welcome to")
                    .fontWeight(.medium)
                    .font(.system(size: 36))

                Text("Pareto Security")
                    .fontWeight(.medium)
                    .font(.system(size: 36))
                    .foregroundColor(.mainColor)
            }
            Spacer(minLength: 20)

            Text("Pareto Security is an app that regularly checks your Mac's security configuration. It helps you take care of 20% of security tasks that prevent 80% of problems.").font(.body).padding(5)
            Spacer(minLength: 20)
            Form {
                VStack(alignment: .leading) {
                    Toggle("Automatically launch on system startup", isOn: $atLogin.isEnabled)
                    Toggle("Send crash reports", isOn: $sendCrashReports)
                }
            }
            Spacer(minLength: 20)
            Button("Get Started") {
                step = Steps.Permissions
            }.buttonStyle(HighlightButtonStyle(color: .mainColor))
        }.frame(width: 320, height: 490, alignment: .center).padding(20)
    }
}

#if DEBUG
    struct IntroViewPreviewsBinding: View {
        @State var step = Steps.Welcome

        var body: some View {
            IntroView(step: $step)
        }
    }

    struct IntroView_Previews: PreviewProvider {
        static var previews: some View {
            IntroViewPreviewsBinding()
        }
    }
#endif
