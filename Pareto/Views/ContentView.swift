//
//  ContentView.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import AppKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pareto")
                .font(Font.system(size: 34.0))
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16.0)
                .padding(.vertical, 12.0)
                .frame(width: 360.0, height: 320.0, alignment: .topLeading)
            Button(action: {
                NSApplication.shared.terminate(self)
            }) {
                Text("Quit App")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.trailing, 16.0)
            .frame(width: 360.0, alignment: .trailing)
        }
        .padding(0)
        .frame(width: 360.0, height: 360.0, alignment: .top)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
