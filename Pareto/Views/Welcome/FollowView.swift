//
//  FollowView.swift
//  Pareto Security
//
//  Created by Janez Troha on 09/11/2021.
//

import Alamofire
import Defaults
import Regex
import SwiftUI

struct FollowView: View {
    @Binding var step: Steps
    @State var subscribed: Bool = false
    @State var email = ""

    var disableForm: Bool {
        subscribed || !Regex("(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$)").isMatched(by: email)
    }

    func subscribe() {
        let parameters: [String: String] = [
            "uuid": Defaults[.machineUUID],
            "version": AppInfo.appVersion,
            "os_version": AppInfo.macOSVersionString,
            "distribution": AppInfo.utmSource,
            "email": email
        ]

        AF.request("https://paretosecurity.com/api/subscribe", method: .post, parameters: parameters)
            .cURLDescription { description in
                debugPrint(description)
            }
            .response { response in
                subscribed = true
                debugPrint(response)
            }
    }

    var body: some View {
        VStack {
            VStack {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80, alignment: .center)
                    .accessibility(hidden: true)
                Text("Get a free personal license!").font(.largeTitle)
                Spacer(minLength: 20)

                if !subscribed {
                    Text("Subscribe to our newsletter and get one free personal license for your family or friend.").font(.body).frame(alignment: .center)
                    HStack(alignment: .center) {
                        TextField("Email address", text: $email)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray, lineWidth: 1)
                            )

                        Button("Subscribe") {
                            subscribe()
                        }.buttonStyle(HighlightButtonStyle(h: 5, v: 5, color: !disableForm ? .mainColor : .systemGray)).padding(10).frame(maxWidth: 130)
                            .disabled(disableForm)
                    }
                    .padding(.leading, 10)
                    Text("We only send security tips and product updates. Unsubscribe at any time.").font(.body).frame(alignment: .center)
                } else {
                    Spacer(minLength: 20)
                    Text("You are now subscribed!").font(.title2)
                    Spacer(minLength: 20)
                }

                Spacer(minLength: 40)
                HStack(alignment: .center) {
                    Image("twitter")
                    Spacer(minLength: 10)
                    VStack(alignment: .leading) {
                        Link("Follow us on Twitter", destination: URL(string: "https://twitter.com/paretosecurity")!)
                        Text("Get announcements and tips in your feed")
                    }
                    Spacer(minLength: 30)
                }
                .padding(10)
                Spacer(minLength: 20)

            }.frame(width: 350, alignment: .center).padding(15)
            Button("Continue") {
                step = Steps.Checks
            }.buttonStyle(HighlightButtonStyle(color: .mainColor)).padding(10)
        }.frame(width: 380, height: 500, alignment: .center).padding(10)
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
