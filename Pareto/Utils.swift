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

func runOSA(appleScript: String) -> String? {
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: appleScript) {
        if let outputString = scriptObject.executeAndReturnError(&error).stringValue {
            os_log("OSA: %{public}s", log: Log.check, type: .debug, outputString)
            return outputString
        } else if let error = error {
            os_log("Failed to execute script\n%{public}@", log: Log.check, type: .error, error.description)
        }
    }

    return nil
}
