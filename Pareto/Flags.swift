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
    @Published var dashboardMenu: Bool = true
    @Published var dashboardMenuAll: Bool = true
    @Published var useEdgeCache: Bool = true
    @Published var teamAPI: Bool = true
    @Published var slowerTeamUpdate: Bool = true
    @Published var setappUpdate: Int = 4
}
