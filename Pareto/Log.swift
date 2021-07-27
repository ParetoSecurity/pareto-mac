import os

private let subsystem = "dev.dz0ny.pareto"

enum Log {
    static let app = OSLog(subsystem: subsystem, category: "App")
    static let check = OSLog(subsystem: subsystem, category: "Check")
}
