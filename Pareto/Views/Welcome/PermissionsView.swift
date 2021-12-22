//
//  PermissiosView.swift
//  Pareto Security
//
//  Created by Janez Troha on 09/11/2021.
//

import SwiftUI

struct PermissionsView: View {
    @Binding var step: Steps
    @State var osaAuthorized = false

    func authorizeOSAClick() {
        let script = "tell application \"System Events\" to tell security preferences to get automatic login"
        osaAuthorized = runOSA(appleScript: script) != nil
    }

    var body: some View {
        VStack {
            VStack {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 60, alignment: .center)
                    .accessibility(hidden: true)

                Text("Configure Permissions").font(.largeTitle)
                Spacer()
                Text("Allow the app read-only access to the system. These permissions do not allow changing or running any of the system settings.").font(.body)
            }.frame(width: 350, alignment: .center).padding(15)
            Spacer(minLength: 30)
            HStack {
                VStack(alignment: .leading) {
                    Text("System Events Access").font(.title2)
                    Text("App requires read-only access to system events so that it can react on connectivity changes, settings changes, and to run checks. ").font(.footnote)
                }
                Button(!osaAuthorized ? "Authorize" : "Authorized") {
                    authorizeOSAClick()
                }.buttonStyle(HighlightButtonStyle(h: 4, v: 4, color: !osaAuthorized ? .mainColor : .systemGray)).frame(width: 80, alignment: .center).disabled(osaAuthorized)
            }.frame(width: 350, alignment: .center)

            if AppInfo.secExp {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Admin Permissions").font(.title2)
                        Text("App requires read-only administrator permissions to run checks.").font(.footnote)
                    }
                    Button("Authorized") {}.buttonStyle(HighlightButtonStyle(h: 4, v: 4, color: .systemGray)).frame(width: 80, alignment: .center)
                }.frame(width: 350, alignment: .center)
            }
            Spacer(minLength: 40)
            Button("Continue") {
                #if SETAPP_ENABLED
                    step = Steps.Follow
                #else
                    step = Steps.Checks
                #endif
            }.buttonStyle(HighlightButtonStyle(color: osaAuthorized ? .mainColor : .systemGray)).padding(10).disabled(!osaAuthorized)
        }.frame(width: 380, height: 430, alignment: .center).padding(10)
    }
}

#if DEBUG
    struct PermissionsViewPreviewsBinding: View {
        @State var step = Steps.Welcome

        var body: some View {
            PermissionsView(step: $step)
        }
    }

    struct PermissionsView_Previews: PreviewProvider {
        static var previews: some View {
            PermissionsViewPreviewsBinding()
        }
    }
#endif
