//
//  NetworkSession.swift
//  Pareto Security
//
//  Created by Claude on 04/12/2025.
//

import Alamofire
import Foundation

enum NetworkSession {
    /// Shared Alamofire session with HTTP failure monitoring
    static let shared: Session = {
        let configuration = URLSessionConfiguration.default
        let monitor = HTTPFailureMonitor()
        return Session(configuration: configuration, eventMonitors: [monitor])
    }()
}
