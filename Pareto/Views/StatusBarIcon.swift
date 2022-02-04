//
//  StatusBarIcon.swift
//  Pareto Security
//
//  Created by Janez Troha on 20/12/2021.
//

import SwiftUI

enum StatusBarState: String {
    case idle = "IconGray"
    case warning = "IconOrange"
    case allOk = "IconGreen"
}

class StatusBarModel: ObservableObject {
    @Published var state = StatusBarState.idle
    @Published var isRunning = false
}

struct StatusBarIcon: View {
    @ObservedObject var statusBarModel: StatusBarModel
    @State private var isBlinking: Bool = false
    @State private var isBlinkingState = StatusBarState.warning
    @State private var fadeOut: Bool = true

    var body: some View {
        ZStack {
            // Moves in from leading out, out to trailing edge.
            if statusBarModel.isRunning {
                ZStack {
                    Image(statusBarModel.state.rawValue)
                        .resizable()
                        .blur(radius: 0.8)
                        .frame(width: 22, height: 20, alignment: .center)
                    ProgressView()
                        .frame(width: 5.0, height: 5.0)
                        .blur(radius: 0.8)
                        .scaleEffect(x: 0.5, y: 0.5, anchor: .center)
                }.onDisappear {
                    self.isBlinking = true
                    self.isBlinkingState = statusBarModel.state == StatusBarState.warning ? StatusBarState.warning : StatusBarState.allOk
                }

            } else {
                if isBlinking {
                    Image(isBlinkingState.rawValue)
                        .resizable()
                        .frame(width: 22, height: 20, alignment: .center)
                        .opacity(fadeOut ? 1 : 0.5)
                        .animation(.easeInOut(duration: 0.3)) // animatable fade in/out
                        .onAppear {
                            let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                                self.fadeOut.toggle() // 1) fade out
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                                isBlinking = false
                                isBlinkingState = StatusBarState.warning
                                fadeOut = true
                                timer.invalidate()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                if statusBarModel.state == .allOk {
                                    statusBarModel.state = .idle
                                }
                            }
                        }
                } else {
                    Image(statusBarModel.state.rawValue)
                        .resizable()
                        .frame(width: 22, height: 20, alignment: .center).onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                if statusBarModel.state == .allOk {
                                    statusBarModel.state = .idle
                                }
                            }
                        }
                }
            }

        }.frame(width: 26, height: 20, alignment: .center)
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
    }
}

struct StatusBarIcon_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarIcon(statusBarModel: StatusBarModel())
    }
}
