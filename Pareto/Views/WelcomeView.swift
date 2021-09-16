//
//  FreeView.swift
//  FreeView
//
//  Created by Janez Troha on 09/09/2021.
//

import Defaults
import SwiftUI

struct WelcomeView: View {
    @State var showDetail = false
    @Default(.lastCheck) var lastCheck
    @Default(.checksPassed) var checksPassed
    var body: some View {
        if !showDetail {
            VStack {
                VStack {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minHeight: 180, alignment: .center)
                        .accessibility(hidden: true)

                    Text("Welcome to")
                        .fontWeight(.black)
                        .font(.system(size: 36))

                    Text("Pareto Security")
                        .fontWeight(.black)
                        .font(.system(size: 36))
                        .foregroundColor(.mainColor)
                }
                Spacer(minLength: 30)
                if lastCheck > 0 {
                    Text("Done! The checks will be performed in the background from now on.").font(.headline)
                    Spacer(minLength: 30)
                    Button("Continue") {
                        showDetail.toggle()
                    }.buttonStyle(HighlightButtonStyle(color: .mainColor))

                } else {
                    Text("Pareto Security is checking your computer's security for the first time.").font(.headline)
                    Spacer(minLength: 30)
                    ProgressView()
                    Spacer(minLength: 20)
                    Button("Please wait a few seconds") {}
                        .buttonStyle(HighlightButtonStyle(color: .gray, font: .headline))
                }

            }.frame(width: 320, alignment: .center).padding(20)

        } else {
            VStack {
                Spacer(minLength: 20)
                if checksPassed {
                    Image(systemName: "checkmark.shield.fill")
                        .resizable()
                        .foregroundColor(.green)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 90, alignment: .center)
                        .accessibility(hidden: true)
                    Spacer(minLength: 20)
                    Text("Your computer is secure. Congrats!").font(.title)
                } else {
                    Image(systemName: "xmark.shield.fill")
                        .resizable()
                        .foregroundColor(.orange)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 90, alignment: .center)
                        .accessibility(hidden: true)
                    Spacer(minLength: 20)
                    Text("There are things you need to reconfigure on your computer.").font(.title)
                }

                Spacer(minLength: 20)
                Button("Show me") {
                    NSApp.sendAction(#selector(AppDelegate.showMenu), to: nil, from: nil)
                    NSApplication.shared.keyWindow?.close()
                }.buttonStyle(HighlightButtonStyle(color: .mainColor, font: .headline))
            }.frame(width: 320, height: 320, alignment: .center).padding(20)
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
