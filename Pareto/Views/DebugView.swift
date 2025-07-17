//
//  DebugView.swift
//  Pareto Security
//
//  Created by Janez Troha on 10/06/2022.
//

import SwiftUI

struct DebugView: View {
    @State private var data = ""
    var body: some View {
        Text(data).fixedSize(horizontal: false, vertical: true).frame(width: 640, height: 480).onAppear {}
    }
}

struct CheckDebugView: View {
    let checkTitle: String
    let debugInfo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Debug Information")
                .font(.title)
                .fontWeight(.bold)

            Text(checkTitle)
                .font(.headline)
                .foregroundColor(.secondary)

            ScrollView {
                Text(debugInfo)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            HStack {
                Spacer()
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(debugInfo, forType: .string)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 640, height: 480)
    }
}

#Preview {
    DebugView()
}

#Preview {
    CheckDebugView(checkTitle: "Time Machine Check", debugInfo: "Sample debug information\nLine 2\nLine 3")
}
