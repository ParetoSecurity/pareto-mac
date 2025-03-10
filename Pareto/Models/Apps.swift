//
//  Apps.swift
//  Pareto Security
//
//  Created by Janez Troha on 14. 03. 24.
//

import Foundation

struct PublicApp: Codable {
    let name: String
    let bundle: String
    let version: String

    static var all: [PublicApp] {
        var detectedApps: [PublicApp] = []
        let allApps = try! FileManager.default.contentsOfDirectory(at: URL(string: "/Applications")!, includingPropertiesForKeys: [.isApplicationKey])
        for app in allApps {
            let plist = PublicApp.readPlistFile(fileURL: app.appendingPathComponent("Contents/Info.plist"))
            if let appName = plist?["CFBundleName"] as? String,
               let appBundle = plist?["CFBundleIdentifier"] as? String {
                let bundleApp = PublicApp(
                    name: appName,
                    bundle: appBundle,
                    version: plist?["CFBundleShortVersionString"] as? String ?? "Unknown"
                )
                detectedApps.append(bundleApp)
            }
        }

        // user apps
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let localPath = URL(fileURLWithPath: "\(homeDirURL.path)/Applications/")
        if (try? localPath.checkResourceIsReachable()) ?? false {
            let userApps = try! FileManager.default.contentsOfDirectory(at: localPath, includingPropertiesForKeys: [.isApplicationKey])
            for app in userApps {
                let plist = PublicApp.readPlistFile(fileURL: app.appendingPathComponent("Contents/Info.plist"))
                if let appName = plist?["CFBundleName"] as? String,
                   let appBundle = plist?["CFBundleIdentifier"] as? String {
                    let bundleApp = PublicApp(
                        name: appName,
                        bundle: appBundle,
                        version: plist?["CFBundleShortVersionString"] as? String ?? "Unknown"
                    )
                    detectedApps.append(bundleApp)
                }
            }
        }

        return detectedApps
    }

    static func readPlistFile(fileURL: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        guard let result = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return result
    }

    static func asJSON() -> String? {
        var export: [PublicApp] = []

        for app in PublicApp.all.sorted(by: { lha, rha in
            lha.name.lowercased() < rha.name.lowercased()
        }) {
            export.append(app)
        }

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        let jsonData = try! jsonEncoder.encode(export)
        guard let json = String(data: jsonData, encoding: String.Encoding.utf8) else { return nil }

        return json
    }
}
