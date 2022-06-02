//
//  ClipButton.swift
//  Pareto Updater
//
//  Created by Janez Troha on 16/05/2022.
//

import Foundation
import SwiftUI

struct ClipButton: ButtonStyle {
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        MyButton(configuration: configuration)
    }

    struct MyButton: View {
        let configuration: ButtonStyle.Configuration

        @Environment(\.isEnabled) private var isEnabled: Bool
        @State private var isOver: Bool = false

        var backgroundColor: Color {
            if !isEnabled {
                return Color.gray.opacity(0.0)
            }
            if isOver {
                return Color.gray.opacity(0.5)
            } else {
                return Color.gray.opacity(0.0)
            }
        }

        var body: some View {
            configuration.label
                .padding(5)
                .foregroundColor(.primary)
                .background(backgroundColor)
                .cornerRadius(8.0)
                .onHover { over in
                    isOver = over
                }.frame(minHeight: 15.0)
                .opacity(isEnabled ? configuration.isPressed ? 0.8 : 1.0 : 0.4)
        }
    }
}

#if DEBUG

    struct ClipButton_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                Button {} label: {
                    Image(systemName: "app")
                }.buttonStyle(ClipButton())
            }.padding(30)
        }
    }
#endif
