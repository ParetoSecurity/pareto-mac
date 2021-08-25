//
//  NSBackgroundActivityScheduler.swift
//  NSBackgroundActivityScheduler
//
//  Created by Janez Troha on 25/08/2021.
//

import Foundation
import SwiftUI

extension NSBackgroundActivityScheduler {
    static func repeating(withInterval: TimeInterval, _ fn: @escaping (NSBackgroundActivityScheduler.CompletionHandler) -> Void) {
        let activity = NSBackgroundActivityScheduler(identifier: "com.niteo.Pareto.UpdateClaims")
        activity.repeats = true
        activity.interval = withInterval
        activity.schedule { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            fn(completion)
        }
    }
}
