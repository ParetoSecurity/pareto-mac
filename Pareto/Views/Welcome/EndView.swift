//
//  EndView.swift
//  Pareto Security
//
//  Created by Janez Troha on 09/11/2021.
//

import Defaults
import SwiftUI

struct EndView: View {
    @Default(.checksPassed) var checksPassed

    var body: some View {
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
        }.frame(width: 320, alignment: .center).padding(20)
    }
}

struct EndView_Previews: PreviewProvider {
    static var previews: some View {
        EndView()
    }
}
