//
//  Utils.swift
//  Utils
//
//  Created by Janez Troha on 30/08/2021.
//

import Foundation
import os.log

func runCMD(app: String, args: [String]) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = args
    task.launchPath = app
    task.launch()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
        task.waitUntilExit()
    } catch {
        return error.localizedDescription
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    return output
}

func runOSA(appleScript: String) -> String? {
    #if !DEBUG
        let out = runCMD(app: "/usr/bin/osascript", args: ["-e", appleScript])
        return out
    #else
        return "debug"
    #endif
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

func HWInfo(forKey key: String) -> String {
    let service = IOServiceGetMatchingService(kIOMasterPortDefault,
                                              IOServiceMatching("IOPlatformExpertDevice"))

    guard let info = (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
        return "Unknown"
    }
    IOObjectRelease(service)
    return info
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
