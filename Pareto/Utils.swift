//
//  Utils.swift
//  Utils
//
//  Created by Janez Troha on 30/08/2021.
//

import Foundation
import os.log
import OSAKit

enum CommandRunnerError: Swift.Error {
    case launchFailed(String)
    case timedOut
}

private final class ProcessBox {
    var process: Process?
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func output() -> String {
        lock.lock()
        let value = String(data: data, encoding: .utf8) ?? ""
        lock.unlock()
        return value
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func run(_ block: () -> Void) {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        resumed = true
        lock.unlock()
        block()
    }
}

func runCMDAsync(app: String, args: [String], timeout: TimeInterval = 15.0) async throws -> String {
    let processBox = ProcessBox()
    let outputBuffer = OutputBuffer()
    let resumeGate = ResumeGate()

    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()

            @Sendable func resumeOnce(_ result: Result<String, Swift.Error>) {
                resumeGate.run {
                    continuation.resume(with: result)
                }
            }

            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = args
            task.launchPath = app
            processBox.process = task

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                outputBuffer.append(data)
            }

            task.terminationHandler = { _ in
                pipe.fileHandleForReading.readabilityHandler = nil
                let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
                if !remaining.isEmpty {
                    outputBuffer.append(remaining)
                }
                let output = outputBuffer.output()
                resumeOnce(.success(output))
            }

            do {
                try task.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                resumeOnce(.failure(CommandRunnerError.launchFailed(error.localizedDescription)))
                return
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                if task.isRunning {
                    task.terminate()
                    resumeOnce(.failure(CommandRunnerError.timedOut))
                }
            }
        }
    } onCancel: {
        if let process = processBox.process, process.isRunning {
            process.terminate()
        }
    }
}

func runCMD(app: String, args: [String]) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = args
    task.launchPath = app
    task.launch()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    let output = String(data: data, encoding: .utf8)!
    return output
}

func runShell(args: [String]) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.arguments = args
    task.standardInput = nil
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    do {
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8)!
        return output
    } catch {
        return error.localizedDescription
    }
}

func runOSA(appleScript: String) -> String? {
    var error: NSDictionary?
    guard let script = NSAppleScript(source: appleScript) else {
        os_log("NSAppleScript init failed")
        return nil
    }
    let result = script.executeAndReturnError(&error)
    if let error = error {
        os_log("NSAppleScript error: %{public}s", error.debugDescription)
        return nil
    }

    // Prefer the string value if available
    if let s = result.stringValue {
        return s
    }

    // As a last resort, try the raw data of the descriptor
    let rawData = result.data
    if let text = String(data: rawData, encoding: .utf8) ?? String(data: rawData, encoding: .macOSRoman) {
        return text
    }

    // Fallback to description
    return result.description
}

func lsof(withCommand cmd: String, withPort port: Int) -> Bool {
    let out = runCMD(app: "/usr/sbin/lsof", args: ["-i", "TCP:\(port)", "-P", "+L", "-O", "-T", "+c", "0", "-nPM"])
    for line in out.components(separatedBy: "\n") {
        if line.hasPrefix(cmd), line.hasSuffix("*:\(port)") {
            return true
        }
    }
    return false
}

func memoize<Input: Hashable, Output>(_ function: @escaping (Input) -> Output) -> (Input) -> Output {
    // our item cache
    var storage = [Input: Output]()

    // send back a new closure that does our calculation
    return { input in
        if let cached = storage[input] {
            return cached
        }

        let result = function(input)
        storage[input] = result
        return result
    }
}

func viaEdgeCache(_ url: String) -> String {
    if AppInfo.Flags.useEdgeCache {
        return url.replacingOccurrences(of: "https://", with: "https://pareto-cache.team-niteo.workers.dev/")
    }
    return url
}
