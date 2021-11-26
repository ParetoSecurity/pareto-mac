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

func lsof(withCommand cmd: String, withPort port: Int) -> Bool {
    let out = runCMD(app: "/usr/sbin/lsof", args: ["-i", "TCP:\(port)", "-P", "+L", "-O", "-T", "+c", "0", "-nPM"])
    for line in out.components(separatedBy: "\n") {
        if line.hasPrefix(cmd), line.hasSuffix("*:\(port)") {
            return true
        }
    }
    return false
}

private class XmlToDictionaryParserDelegate: NSObject, XMLParserDelegate {
    private var currentElement: XmlElement?

    fileprivate init(_ element: XmlElement) {
        currentElement = element
    }

    public func parser(_: XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?) {
        currentElement = currentElement?.pop(elementName)
    }

    public func parser(_: XMLParser, didStartElement elementName: String, namespaceURI _: String?, qualifiedName _: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = currentElement?.push(elementName)
        currentElement?.attributeDict = attributeDict
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        currentElement?.text += string
    }
}

public class XmlElement {
    public private(set) var name = "unnamed"
    public private(set) var children = [String: XmlElement]()
    public private(set) var parent: XmlElement?
    public fileprivate(set) var text = ""
    public fileprivate(set) var attributeDict: [String: String] = [:]

    private init(_ parent: XmlElement? = nil, name: String = "") {
        self.parent = parent
        self.name = name
    }

    public convenience init?(fromString: String) {
        guard let data = fromString.data(using: .utf8) else {
            return nil
        }
        self.init(fromData: data)
    }

    public init(fromData: Data) {
        let parser = XMLParser(data: fromData)
        let delegate = XmlToDictionaryParserDelegate(self)
        parser.delegate = delegate
        parser.parse()
    }

    fileprivate func push(_ elementName: String) -> XmlElement {
        let childElement = XmlElement(self, name: elementName)
        children[elementName] = childElement
        return childElement
    }

    fileprivate func pop(_ elementName: String) -> XmlElement? {
        assert(elementName == name)
        return parent
    }

    public subscript(name: String) -> XmlElement? {
        return children[name]
    }
}
