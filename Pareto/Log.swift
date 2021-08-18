import os

private let subsystem = "niteo.co.Pareto"

enum Log {
    static let app = OSLog(subsystem: subsystem, category: "Apps")
    static let check = OSLog(subsystem: subsystem, category: "Check")
}
