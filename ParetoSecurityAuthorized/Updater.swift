//
//  Updater.swift
//  SwiftAuthorizationSample
//
//  Created by Josh Kaplan on 2021-10-24
//

import Foundation
import EmbeddedPropertyList

/// An in-place updater for the helper tool.
///
/// To keep things simple, this updater only works if `launchd` property lists do not change between versions.
enum Updater {
    
    /// Replaces itself with the helper tool located at the provided `URL` so long as security, launchd, and version requirements are met.
    ///
    /// - Parameters:
    ///   - atPath: Path to the helper tool.
    /// - Throws: If the helper tool file can't be read, public keys can't be determined, or `launchd` property lists can't be compared.
    static func updateHelperTool(atPath helperTool: URL) throws {
        if try CodeInfo.doesPublicKeyMatch(forExecutable: helperTool) {
            if try launchdPropertyListsMatch(forHelperTool: helperTool) {
                let (isNewer, currentVersion, otherVersion) = try isHelperToolNewerVersion(atPath: helperTool)
                if isNewer {
                    let helperToolData = try Data(contentsOf: helperTool)
                    try helperToolData.write(to: try CodeInfo.currentCodeLocation(), options: .atomicWrite)
                    NSLog("update succeeded: exiting current version...")
                    exit(0)
                } else {
                    NSLog("update failed: not a newer version. current: \(currentVersion), other: \(otherVersion).")
                }
            } else {
                NSLog("update failed: launchd property list has changed")
            }
        } else {
            NSLog("update failed: security requirements not met")
        }
    }
    
    /// Determines if the helper tool located at the provided `URL` is actually an update.
    ///
    /// - Parameters:
    ///   - atPath: Path to the helper tool.
    /// - Throws: If unable to read the info property lists of this helper tool or the one located at `atPath`.
    /// - Returns: If the helper tool at the location specified by `atPath` is newer than the one running this code and the versions of both.
    private static func isHelperToolNewerVersion(atPath helperTool: URL)
        throws -> (isNewer: Bool, current: BundleVersion, other: BundleVersion) {
        let current = try HelperToolInfoPropertyList.main().version
        let other = try HelperToolInfoPropertyList.init(from: helperTool).version
        
        return (other > current, current, other)
    }
    
    /// Determines if the `launchd` property list used by this helper tool and the executable located at the provided `URL` are byte-for-byte identical.
    ///
    /// - Parameters:
    ///   - forHelperTool: Path to the helper tool.
    /// - Throws: If unable to read the launchd property lists of this helper tool or the one located at `forHelperTool`.
    /// - Returns: If the two launchd property lists match.
    ///
    /// This matters because only the helper tool itself is being updated, the property list generated for launchd will not be updated as part of this update process.
    private static func launchdPropertyListsMatch(forHelperTool helperTool: URL) throws -> Bool {
        let current = try EmbeddedPropertyListReader.launchd.readInternal()
        let other = try EmbeddedPropertyListReader.launchd.readExternal(from: helperTool)
        
        return current == other
    }
}
