//
//  PermissiosView.swift
//  Pareto Security
//
//  Created by Janez Troha on 09/11/2021.
//

import SwiftUI

struct FollowView: View {
    @Binding var step: Steps
    @State var osaAuthorized = false

    var body: some View {
        VStack {
            VStack {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 60, alignment: .center)
                    .accessibility(hidden: true)

                Text("Configure Permissions").font(.title)
                Spacer()
                Text("Allow the app read-only access to the system. These permissions do not allow changing or running any of the system settings.").font(.body)
            }.frame(width: 350, alignment: .center).padding(15)
            Spacer(minLength: 40)
            Button("Continue") {
                step = Steps.Checks
            }.buttonStyle(HighlightButtonStyle(color: osaAuthorized ? .mainColor : .systemGray)).padding(10)
        }.frame(width: 380, height: 430, alignment: .center).padding(10)
    }
}

#if DEBUG
    struct FollowViewPreviewsBinding: View {
        @State var step = Steps.Welcome

        var body: some View {
            FollowView(step: $step)
        }
    }

    struct FollowView_Previews: PreviewProvider {
        static var previews: some View {
            FollowViewPreviewsBinding()
        }
    }
#endif
