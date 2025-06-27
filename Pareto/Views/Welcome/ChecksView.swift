//
//  ChecksView.swift
//  Pareto Security
//
//  Created by Janez Troha on 09/11/2021.
//

import Defaults
import SwiftUI

struct ChecksView: View {
    @Binding var step: Steps
    @Default(.lastCheck) var lastCheck

    var body: some View {
        VStack {
            VStack {
                Image("Icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minHeight: 180, alignment: .center)
                    .accessibility(hidden: true)
            }
            Spacer(minLength: 30)
            if lastCheck > 0 {
                Text("Done!").font(.largeTitle)
                Spacer(minLength: 20)
                Text("The checks will be performed in the background from now on.").font(.body)
                Spacer(minLength: 30)
                Button("Continue") {
                    step = Steps.End
                }.buttonStyle(HighlightButtonStyle(color: .mainColor))

            } else {
                Text("Pareto Security is checking your computer's security for the first time.").font(.body)
                Spacer(minLength: 20)
                ProgressView()
                Spacer(minLength: 30)
                Button("Please wait a few seconds") {}
                    .buttonStyle(HighlightButtonStyle(color: .gray, font: .headline))
            }

        }.frame(width: 320, alignment: .center).padding(20).onAppear {
            NSApp.sendAction(#selector(AppDelegate.runChecksDelayed), to: nil, from: nil)
        }
    }
}

#if DEBUG
    struct ChecksViewPreviewsBinding: View {
        @State var step = Steps.Checks

        var body: some View {
            ChecksView(step: $step)
        }
    }

    struct ChecksView_Previews: PreviewProvider {
        static var previews: some View {
            ChecksViewPreviewsBinding()
        }
    }
#endif
