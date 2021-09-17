//
//  FreeView.swift
//  FreeView
//
//  Created by Janez Troha on 09/09/2021.
//

import Defaults
import SwiftUI

private extension AnyTransition {
    static var moveAndFade: AnyTransition {
        AnyTransition.slide
    }
}

struct GrayButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .font(.headline)
            .padding()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.gray))
            .padding(.bottom)
    }
}

struct BlueButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .font(.headline)
            .padding()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.blue))
            .padding(.bottom)
    }
}

private extension Text {
    func customTitleText() -> Text {
        fontWeight(.black)
            .font(.system(size: 36))
    }
}

private extension Color {
    init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: Double(CGFloat(red)) / 255.0, green: Double(CGFloat(green)) / 255.0, blue: Double(CGFloat(blue)) / 255.0)
    }

    init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }

    static var mainColor = Color(rgb: 0x4C84E2)
}

struct TitleView: View {
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(minHeight: 180, alignment: .center)
                .accessibility(hidden: true)

            Text("Welcome to")
                .customTitleText()

            Text("Pareto Security")
                .customTitleText()
                .foregroundColor(.mainColor)
        }
    }
}

struct WelcomeView: View {
    @State private var showDetail = true
    @Default(.lastCheck) var lastCheck
    @Default(.checksPassed) var checksPassed
    var body: some View {
        if showDetail {
            VStack {
                TitleView()
                Spacer(minLength: 30)
                if lastCheck > 0 {
                    Text("Done! The checks will be performed in the background from now on.").font(.headline)
                    Spacer(minLength: 30)
                    Button("Continue") {
                        showDetail.toggle()
                    }.buttonStyle(BlueButton())

                } else {
                    Text("Pareto Security is checking your computer's security for the first time.").font(.headline)
                    Spacer(minLength: 30)
                    ProgressView()
                    Spacer(minLength: 20)
                    Button("Please wait a few seconds") {}.buttonStyle(GrayButton())
                }

            }.frame(width: 320, alignment: .center).padding(20).transition(.moveAndFade)

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
                }.buttonStyle(BlueButton())
            }.frame(width: 320, height: 320, alignment: .center).padding(20).transition(.moveAndFade)
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
