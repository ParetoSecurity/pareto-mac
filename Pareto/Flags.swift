//
//  Flags.swift
//  Flags
//
//  Created by Janez Troha on 14/09/2021.
//

import Alamofire
import Combine
import Foundation
import os.log

class FlagsUpdater: ObservableObject {
    @Published var personalLicenseSharing: Bool = true
    @Published var dashboardMenu: Bool = true
    @Published var dashboardMenuAll: Bool = true
    @Published var useEdgeCache: Bool = true
    @Published var teamAPI: Bool = true
    @Published var slowerTeamUpdate: Bool = true
    @Published var nagScreenDelayDays: Int = 30
    @Published var setappUpdate: Int = 4
}
