//
//  FirewallExceptions.swift
//  Pareto Security
//
//  Created by ArchitektApx on 06/11/2026.
//

import Defaults
import Foundation
import os.log

class FirewallExceptionsCheck: ParetoCheck {
    static let sharedInstance = FirewallExceptionsCheck()

    struct App: Equatable {
        let path: String
        let allowsIncoming: Bool
    }

    let listAppsProvider: () -> String?
    let requiresHeader: Bool

    init(
        listAppsProvider: @escaping () -> String? = { FirewallExceptionsCheck.listApps() },
        requiresHeader: Bool = FirewallExceptionsCheck.alwaysPrintsHeader
    ) {
        self.listAppsProvider = listAppsProvider
        self.requiresHeader = requiresHeader
    }

    /// macOS 13 and 14 print nothing for an empty list, macOS 15 and later always print the header.
    static var alwaysPrintsHeader: Bool {
        if #available(macOS 15, *) {
            return true
        }
        return false
    }

    override var UUID: String {
        "783c9607-b3dc-4a79-8d27-0f337e018c4b"
    }

    override var TitleON: String {
        "Firewall has no app exceptions"
    }

    override var TitleOFF: String {
        "Firewall has app exceptions"
    }

    override var isRunnable: Bool {
        if teamEnforced {
            return true
        }
        if !FirewallCheck.sharedInstance.isActive || !isActive {
            return false
        }
        return true
    }

    override var showSettings: Bool {
        if teamEnforced {
            return false
        }
        return FirewallCheck.sharedInstance.isActive
    }

    override var details: String {
        let paths = exceptions() ?? []
        if paths.isEmpty {
            return "None"
        }
        return paths.map { "- \($0)" }.joined(separator: "\n")
    }

    static func listApps(app: String = "/usr/libexec/ApplicationFirewall/socketfilterfw") -> String? {
        let timeout: TimeInterval = 15
        let output = OSAllocatedUnfairLock<String?>(initialState: nil)
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                let result = try await runCMDAsync(
                    app: app,
                    args: ["--listapps"],
                    timeout: timeout,
                    includeStandardError: false,
                    requireSuccessfulExit: true
                )
                output.withLock { $0 = result }
            } catch {
                os_log("socketfilterfw --listapps failed: %{public}@", log: Log.check, String(describing: error))
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + timeout + 1)
        return output.withLock { $0 }
    }

    /// Parses `socketfilterfw --listapps`. macOS 13 and 14 print "ALF: total number of apps = N", blank lines and
    /// "( Allow incoming connections )"; macOS 15 and later print "Total number of apps = N" and
    /// "(Allow incoming connections)". Each app is an "N : <path>" line followed by its status line.
    static func parseListApps(_ output: String, requiresHeader: Bool = alwaysPrintsHeader) -> [App]? {
        let lines = output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let header = lines.first else {
            return requiresHeader ? nil : []
        }
        let count = ["ALF: total number of apps = ", "Total number of apps = "]
            .first { header.hasPrefix($0) }
            .flatMap { Int(header.dropFirst($0.count)) }
        guard let count, lines.count % 2 == 1, (lines.count - 1) / 2 == count else {
            return nil
        }

        var apps: [App] = []
        for index in 0 ..< count {
            let entry = lines[1 + index * 2]
            let prefix = "\(index + 1) :"
            guard entry.hasPrefix(prefix) else {
                return nil
            }
            let path = entry.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty else {
                return nil
            }
            let allowsIncoming: Bool
            switch lines[2 + index * 2] {
            case "( Allow incoming connections )", "(Allow incoming connections)":
                allowsIncoming = true
            case "( Block incoming connections )", "(Block incoming connections)":
                allowsIncoming = false
            default:
                return nil
            }
            apps.append(App(path: path, allowsIncoming: allowsIncoming))
        }
        return apps
    }

    func exceptions() -> [String]? {
        guard let output = listAppsProvider(),
              let apps = Self.parseListApps(output, requiresHeader: requiresHeader)
        else {
            return nil
        }
        let ignored = Defaults[.ignoredFirewallApps]
        return apps.filter { $0.allowsIncoming && !ignored.contains($0.path) }.map(\.path)
    }

    override func checkPasses() -> Bool {
        guard let paths = exceptions() else {
            os_log("Could not read socketfilterfw --listapps output", log: Log.check)
            hasError = true
            return false
        }
        return paths.isEmpty
    }
}
