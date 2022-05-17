//
//  AllowedProcessRunner.swift
//  SwiftAuthorizationSample
//
//  Created by Josh Kaplan on 2021-10-24
//

import Foundation
import Blessed

/// Runs an allowed command.
struct AllowedCommandRunner {
    // Not intended to be constructed, this is used as a namespace
    private init() { }
    
    /// Errors that prevent an allowed command from being run.
    enum AllowedCommandError: Error {
        case authorizationMissing
        case authorizationFailed
    }
    
    /// Runs the allowed command and replies with the results.
    ///
    /// If authorization is needed, the user will be prompted.
    ///
    /// - Parameter message: Message containing the command to run, and if applicable the authorization.
    /// - Returns: The results of running the command.
    static func run(message: AllowedCommandMessage) throws -> AllowedCommandReply {
        // Prompt user to authorize if needed
        if message.command.requiresAuth {
            if let authorization = message.authorization {
                let rights = try authorization.requestRights([SharedConstants.exampleRight],
                                                             environment: [],
                                                             options: [.interactionAllowed, .extendRights])
                if !rights.contains(where: { $0.name == SharedConstants.exampleRight.name }) {
                    throw AllowedCommandError.authorizationFailed
                }
            } else {
                throw AllowedCommandError.authorizationMissing
            }
        }
        
        // Launch process
        let process = Process()
        process.launchPath = message.command.launchPath
        process.arguments = message.command.arguments
        process.qualityOfService = QualityOfService.userInitiated
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.launch()
        process.waitUntilExit()
        
        // Process and return response
        let terminationStatus = Int64(process.terminationStatus)
        var standardOutput: String?
        var standardError: String?
        if let output = String(data: outputPipe.fileHandleForReading.availableData,
                               encoding: String.Encoding.utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           output.count != 0 {
            standardOutput = output
        }
        if let error = String(data: errorPipe.fileHandleForReading.availableData,
                              encoding: String.Encoding.utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           error.count != 0 {
            standardError = error
        }
        outputPipe.fileHandleForReading.closeFile()
        errorPipe.fileHandleForReading.closeFile()
        
        return AllowedCommandReply(terminationStatus: terminationStatus,
                                   standardOutput: standardOutput,
                                   standardError: standardError)
    }
}
