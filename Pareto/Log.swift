import os

private let subsystem = "niteo.co.Pareto"

enum Log {
    static let app = OSLog(subsystem: subsystem, category: "App")
    static let check = OSLog(subsystem: subsystem, category: "Check")
    static let api = OSLog(subsystem: subsystem, category: "API")
}
