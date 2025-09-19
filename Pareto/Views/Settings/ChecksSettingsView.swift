//
//  ChecksSettingsView.swift
//  CheckSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

// Wrapper to avoid state modification during view updates
struct CheckWrapper: Identifiable {
    let id = UUID()
    let check: ParetoCheck
}

struct ChecksSettingsView: View {
    @State private var selectedCheckWrapper: CheckWrapper?
    @Default(.teamID) var teamID

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !teamID.isEmpty {
                        TeamEnforcementHeader()
                    }

                    // Security Check Sections
                    ForEach(Claims.global.all, id: \.self) { claim in
                        CheckSectionView(
                            claimTitle: claim.title,
                            installedChecks: claim.checksSorted.filter { $0.isInstalled },
                            onSelect: { check in
                                selectedCheckWrapper = CheckWrapper(check: check)
                            }
                        )
                    }

                    Link("Learn more about security checks →", destination: URL(string: "https://paretosecurity.com/mac/checks?utm_source=\(AppInfo.utmSource)")!)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
        }
        .padding(10)
        .frame(minHeight: 450)
        .sheet(item: $selectedCheckWrapper) { wrapper in
            if wrapper.check.UUID == NoUnusedUsers.sharedInstance.UUID {
                NoUnusedUsersDetailView(check: wrapper.check)
            } else {
                CheckDetailView(check: wrapper.check)
            }
        }
    }
}

struct CheckSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChecksSettingsView()
    }
}
