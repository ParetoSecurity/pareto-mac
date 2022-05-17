//
//  Uninstaller.swift
//  SwiftAuthorizationSample
//
//  Created by Josh Kaplan on 2021-10-24
//

import Foundation

/// A self uninstaller which performs the logical equivalent of the non-existent `SMJobUnbless`.
///
/// Because Apple does not provide an API to perform an "unbless" operation, the technique used here relies on a few key behaviors:
///  - To deregister the helper tool with launchd, the `launchctl` command line utility which ships with macOS is used
///     - The `unload` command used is publicly documented
///  - An assumption that this helper tool when installed is located at `/Library/PrivilegedHelperTools/<helper_tool_name>`
///     - While this location is not documented in `SMJobBless`, it is used in Apple's EvenBetterAuthorizationSample `Uninstall.sh` script
///     - This is used to determine if this helper tool is in fact running from the blessed location
///  - To remove the `launchd` property list, its location is assumed to be `/Library/LaunchDaemons/<helper_tool_name>.plist`
///     - While this location is not documented in `SMJobBless`, it is used in Apple's EvenBetterAuthorizationSample `Uninstall.sh` script
enum Uninstaller {
    
    /// Errors that prevent the uninstall from succeeding.
    enum UninstallError: Error {
        /// Uninstall will not be performed because this code is not running from the blessed location.
        case notRunningFromBlessedLocation
        /// Attempting to unload using `launchctl` failed.
        ///
        /// The associated value is the underlying status code.
        case launchctlFailure(Int32)
        /// The argument provided must be a process identifier, but was not.
        case notProcessId
    }
    
    /// Command line argument that identifies to `main` to call the  `uninstallFromCommandLine(...)` function.
    static let commandLineArgument = "uninstall"
    
    /// Indirectly uninstalls this helper tool. Calling this function will terminate this process unless an error is throw.
    ///
    /// Uninstalls this helper tool by relaunching itself not via XPC such that the installation can occur succesfully.
    ///
    /// - Throws: If unable to determine the on disk location of this running code.
    static func uninstallFromXPC() throws {
        NSLog("uninstall requested, PID \(getpid())")
        let process = Process()
        process.launchPath = try CodeInfo.currentCodeLocation().path
        process.qualityOfService = QualityOfService.utility
        process.arguments = [commandLineArgument, String(getpid())]
        process.launch()
        NSLog("about to exit...")
        exit(0)
    }
    
    /// Directly uninstalls this executable. Calling this function will terminate this process unless an error is throw.
    ///
    /// Depending on the the arguments provided to this function, it may wait on another process to exit before performing the uninstall.
    ///
    /// - Parameters:
    ///   - withArguments: The command line arguments; the first argument should always be `uninstall`.
    /// - Throws: If unable to perform the uninstall, including because the provided arguments are invalid.
    static func uninstallFromCommandLine(withArguments arguments: [String]) throws -> Never {
        if arguments.count == 1 {
            try uninstallImmediately()
        } else {
            guard let pid: pid_t = Int32(arguments[1]) else {
                throw UninstallError.notProcessId
            }
            try uninstallAfterProcessExits(pid: pid)
        }
    }

    /// Uninstalls this helper tool after waiting for a process (in practice this helper tool launched via XPC) to terminate.
    ///
    /// - Parameters:
    ///   - pid: Identifier for the process which must terminate before performing uninstall. In practice this is identifier is for is a previous run of this helper tool.
    private static func uninstallAfterProcessExits(pid: pid_t) throws -> Never {
        // When passing 0 as the second argument, no signal is sent, but existence and permission checks are still
        // performed. This checks for the existence of a process ID. If 0 is returned the process still exists, so loop
        // until 0 is no longer returned.
        while kill(pid, 0) == 0 { // in practice this condition almost always evaluates to false on its first check
            usleep(50 * 1000) // sleep for 50ms
            NSLog("PID \(getpid()) waited 50ms for PID \(pid)")
        }
        NSLog("PID \(getpid()) done waiting for PID \(pid)")
        
        try uninstallImmediately()
    }
    
    /// Uninstalls this helper tool.
    ///
    /// This function will not work if called when this helper tool was started by an XPC call because `launchctl` will be unable to unload.
    ///
    /// If the uninstall fails when deleting either the `launchd` property list for this executable or the on disk representation of this helper tool then the uninstall
    /// will be an incomplete state; however, it will no longer be started by `launchd` (and in turn not accessible via XPC) and so will be mostly uninstalled even
    /// though some on disk portions will remain.
    ///
    /// - Throws: Due to one of: unable to determine the on disk location of this running code, that location is not the blessed location, `launchctl` can't
    /// unload this helper tool, the `launchd` property list for this helper tool can't be deleted, or the on disk representation of this helper tool can't be deleted.
    private static func uninstallImmediately() throws -> Never {
        let sharedConstants = try SharedConstants(caller: .helperTool)
        let currentLocation = try CodeInfo.currentCodeLocation()
        if currentLocation != sharedConstants.blessedLocation {
            throw UninstallError.notRunningFromBlessedLocation
        }
        
        // Equivalent to: launchctl unload /Library/LaunchDaemons/<helper tool name>.plist
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.qualityOfService = QualityOfService.utility
        process.arguments = ["unload", sharedConstants.blessedPropertyListLocation.path]
        process.launch()
        NSLog("about to wait for launchctl...")
        process.waitUntilExit()
        let terminationStatus = process.terminationStatus
        if terminationStatus == 0 {
            NSLog("unloaded from launchctl")
        } else {
            throw UninstallError.launchctlFailure(terminationStatus)
        }
        
        // Equivalent to: rm /Library/LaunchDaemons/<helper tool name>.plist
        try FileManager.default.removeItem(at: sharedConstants.blessedPropertyListLocation)
        NSLog("property list deleted")
        
        // Equivalent to: rm /Library/PrivilegedHelperTools/<helper tool name>
        try FileManager.default.removeItem(at: sharedConstants.blessedLocation)
        NSLog("helper tool deleted")
        NSLog("uninstall completed, exiting...")
        exit(0)
    }
}
