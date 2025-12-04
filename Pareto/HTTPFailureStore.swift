//
//  HTTPFailureStore.swift
//  Pareto Security
//
//  Created by Claude on 04/12/2025.
//

import Foundation
import os.log

@MainActor
class HTTPFailureStore: ObservableObject {
    static let shared = HTTPFailureStore()

    @Published private(set) var failures: [FailedRequest] = []

    private let maxFailures = 50

    private init() {}

    var hasFailures: Bool {
        !failures.isEmpty
    }

    var latestFailure: FailedRequest? {
        failures.first
    }

    var failureCount: Int {
        failures.count
    }

    func add(_ failure: FailedRequest) {
        os_log("HTTP failure recorded: %{public}@ %{public}@", log: Log.network, failure.method, failure.url)

        failures.insert(failure, at: 0)

        // Keep only the most recent failures
        if failures.count > maxFailures {
            failures = Array(failures.prefix(maxFailures))
        }
    }

    func clear() {
        os_log("Clearing all HTTP failures", log: Log.network)
        failures.removeAll()
    }

    func remove(_ failure: FailedRequest) {
        failures.removeAll { $0.id == failure.id }
    }
}
