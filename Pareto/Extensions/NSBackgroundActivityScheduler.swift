//
//  NSBackgroundActivityScheduler.swift
//  NSBackgroundActivityScheduler
//
//  Created by Janez Troha on 25/08/2021.
//

import Foundation
import SwiftUI

extension NSBackgroundActivityScheduler {
    static func repeating(withName name: String, withInterval: TimeInterval, _ fn: @escaping (NSBackgroundActivityScheduler.CompletionHandler) -> Void) {
        let activity = NSBackgroundActivityScheduler(identifier: "\(Bundle.main.bundleIdentifier!).\(name)")
        activity.repeats = true
        activity.interval = withInterval
        activity.qualityOfService = .userInteractive
        activity.tolerance = TimeInterval(1)
        activity.schedule { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            fn(completion)
        }
    }
}
