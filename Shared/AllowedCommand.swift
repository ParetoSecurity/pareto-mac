//
//  AllowedCommand.swift
//  SwiftAuthorizationSample
//
//  Created by Josh Kaplan on 2021-10-24
//

import Foundation
import Blessed

/// Commands which the helper tool is able to run.
///
/// By making this an enum, any other values will fail to properly decode. This prevents non-approved values from being sent by some other (malicious) process on
/// the system or if the intended caller was compromised. This limits the potential damage by restricting the possible actions the helper tool is able to perform.
enum AllowedCommand: Codable, CaseIterable {
    case whoami
    case systemsetup(SystemSetupArgs)
    case thermal(ThermalArgs)
    
    /// Arguments for systemsetup.
    enum SystemSetupArgs: String, Codable, CaseIterable {
        case getsleep = "-getsleep"
        case getcomputername = "-getcomputername"
        case getlocalsubnetname = "-getlocalsubnetname"
        case liststartupdisks = "-liststartupdisks"
        
        /// Whether providing this arg to `systemsetup` should require additional user authentication.
        ///
        /// This is completely arbitrary and was just done for example purposes.
        var requiresAuth: Bool {
            switch self {
                case .getcomputername:
                    return true
                case .getlocalsubnetname:
                    return true
                default:
                    return false
            }
        }
    }
    
    /// Arguments for thermal.
    enum ThermalArgs: String, Codable, CaseIterable {
        case levels = "levels"
        case config = "config"
        
        /// Whether providing this arg to `thermal` should require additional user authentication.
        ///
        /// This is completely arbitrary and was just done for example purposes.
        var requiresAuth: Bool {
            return false
        }
    }
    
    /// All of the cases with all possible argument values.
    static var allCases: [AllowedCommand] {
        var cases = [AllowedCommand]()
        cases.append(.whoami)
        for arg in SystemSetupArgs.allCases {
            cases.append(.systemsetup(arg))
        }
        for arg in ThermalArgs.allCases {
            cases.append(.thermal(arg))
        }
        
        return cases
    }
    
    /// The location of this executable to be run.
    var launchPath: String {
        switch self {
            case .whoami:
                return "/usr/bin/whoami"
            case .systemsetup:
                return "/usr/sbin/systemsetup"
            case .thermal:
                return "/usr/bin/thermal"
        }
    }
    
    /// The arguments to pass to the executable; can be an empty array if there are none.
    var arguments: [String] {
        switch self {
            case .whoami:
                return []
            case .systemsetup(let systemSetupArgs):
                return [systemSetupArgs.rawValue]
            case .thermal(let thermalArgs):
                return [thermalArgs.rawValue]
        }
    }
    
    /// Whether running this command should result in the user having to authenticate.
    ///
    /// Which ones require authentication is completely arbitrary, this was just done for example purposes.
    var requiresAuth: Bool {
        switch self {
            case .whoami:
                return false
            case .systemsetup(let systemSetupArgs):
                return systemSetupArgs.requiresAuth
            case .thermal(let thermalArgs):
                return thermalArgs.requiresAuth
        }
    }
    
    /// How this command should be visually displayed to a user.
    var displayName: String {
        let executable = String(launchPath.split(separator: "/").last ?? launchPath.dropFirst(0))
        let formattedArguments = arguments.joined(separator: " ")
        let auth = requiresAuth ? "[Auth Required]" : ""
        
        return "\(executable) \(formattedArguments) \(auth)"
    }
}

/// A message sent to the helper tool containing a command potentially an authorization instance.
struct AllowedCommandMessage: Codable {
    let command: AllowedCommand
    let authorization: Authorization?
}

/// A reply containing the results of the helper tool running a command.
struct AllowedCommandReply: Codable {
    let terminationStatus: Int64
    let standardOutput: String?
    let standardError: String?
}
