//
//  ParetoHelper.swift
//  ParetoHelper
//
//  Created by Janez Troha on 15/11/2021.
//

import Foundation

let kAuthorizationRightKeyClass = "class"
let kAuthorizationRightKeyGroup = "group"
let kAuthorizationRightKeyRule = "rule"
let kAuthorizationRightKeyTimeout = "timeout"
let kAuthorizationRightKeyVersion = "version"

let kAuthorizationFailedExitCode = NSNumber(value: 503_340)

enum HelperConstants {
    static let machServiceName = "niteo.co.ParetoHelper"
}

class ParetoHelper: NSObject, NSXPCListenerDelegate, HelperProtocol {
    // MARK: -

    // MARK: Private Constant Variables

    private let listener: NSXPCListener

    // MARK: -

    // MARK: Private Variables

    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0

    // MARK: -

    // MARK: Initialization

    override init() {
        listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        super.init()
        listener.delegate = self
    }

    public func run() {
        listener.resume()

        // Keep the helper tool running until the variable shouldQuit is set to true.
        // The variable should be changed in the "listener(_ listener:shoudlAcceptNewConnection:)" function.
        while !shouldQuit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: shouldQuitCheckInterval))
        }
    }

    // MARK: -

    // MARK: NSXPCListenerDelegate Methods

    func listener(_: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Verify that the calling application is signed using the same code signing certificate as the helper
        guard isValid(connection: connection) else {
            return false
        }

        // Set the protocol that the calling application conforms to.
        connection.remoteObjectInterface = NSXPCInterface(with: AppProtocol.self)

        // Set the protocol that the helper conforms to.
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self

        // Set the invalidation handler to remove this connection when it's work is completed.
        connection.invalidationHandler = {
            if let connectionIndex = self.connections.firstIndex(of: connection) {
                self.connections.remove(at: connectionIndex)
            }

            if self.connections.isEmpty {
                self.shouldQuit = true
            }
        }

        connections.append(connection)
        connection.resume()

        return true
    }

    // MARK: -

    // MARK: HelperProtocol Methods

    func getVersion(completion: (String) -> Void) {
        completion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
    }

    func runCommandLs(withPath path: String, completion: @escaping (NSNumber) -> Void) {
        // For security reasons, all commands should be hardcoded in the helper
        let command = "/bin/ls"
        let arguments = [path]

        // Run the task
        runTask(command: command, arguments: arguments, completion: completion)
    }

    func runCommandLs(withPath path: String, authData: NSData?, completion: @escaping (NSNumber) -> Void) {
        // Check the passed authorization, if the user need to authenticate to use this command the user might be prompted depending on the settings and/or cached authentication.
        guard verifyAuthorization(authData, forCommand: #selector(HelperProtocol.runCommandLs(withPath:authData:completion:))) else {
            completion(kAuthorizationFailedExitCode)
            return
        }

        runCommandLs(withPath: path, completion: completion)
    }

    // MARK: -

    // MARK: Private Helper Methods

    private func isValid(connection: NSXPCConnection) -> Bool {
        do {
            return try CodesignCheck.codeSigningMatches(pid: connection.processIdentifier)
        } catch {
            NSLog("Code signing check failed with error: \(error)")
            return false
        }
    }

    private func verifyAuthorization(_ authData: NSData?, forCommand command: Selector) -> Bool {
        do {
            try HelperAuthorization.verifyAuthorization(authData, forCommand: command)
        } catch {
            if let remoteObject = connection()?.remoteObjectProxy as? AppProtocol {
                remoteObject.log(stdErr: "Authentication Error: \(error)")
            }
            return false
        }
        return true
    }

    private func connection() -> NSXPCConnection? {
        return connections.last
    }

    private func runTask(command: String, arguments: [String], completion: @escaping ((NSNumber) -> Void)) {
        let task = Process()
        let stdOut = Pipe()

        let stdOutHandler = { (file: FileHandle!) in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection()?.remoteObjectProxy as? AppProtocol {
                remoteObject.log(stdOut: output as String)
            }
        }
        stdOut.fileHandleForReading.readabilityHandler = stdOutHandler

        let stdErr = Pipe()
        let stdErrHandler = { (file: FileHandle!) in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection()?.remoteObjectProxy as? AppProtocol {
                remoteObject.log(stdErr: output as String)
            }
        }
        stdErr.fileHandleForReading.readabilityHandler = stdErrHandler

        task.launchPath = command
        task.arguments = arguments
        task.standardOutput = stdOut
        task.standardError = stdErr

        task.terminationHandler = { task in
            completion(NSNumber(value: task.terminationStatus))
        }

        task.launch()
    }
}
