//
//  CustomCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 30/07/2022.
//

import Foundation
import Yams

struct CustomCheckResult: Codable {
    var integer: Int?
    var string: String?
}

struct CustomCheck: Codable {
    var id: String
    var title: String
    var check: String
    var url: String?
    var discussion: String?
    var fix: String?
    var result: CustomCheckResult

    var command: String {
        check.trim()
    }

    func passes() -> Bool {
        let res = runShell(args: ["-c", command]).trim()
        if let asInt = result.integer {
            return Int(res) == asInt
        }
        if let asString = result.string {
            return res == asString
        }
        return false
    }

    static func getRules() -> [CustomCheck] {
        var checks = [CustomCheck]()
        do {
            // Get the document directory url
            let documentDirectory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("ParetoAuditor", conformingTo: .directory)

            print("documentDirectory", documentDirectory.path)
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: documentDirectory,
                includingPropertiesForKeys: nil
            )

            for fileURL in directoryContents.filter({ $0.lastPathComponent.contains(".yaml") }) {
                do {
                    let decoder = YAMLDecoder()
                    let data = try String(contentsOf: fileURL, encoding: .utf8)
                    let decoded = try decoder.decode(CustomCheck.self, from: data)
                    checks.append(decoded)
                } catch {
                    print(error)
                }
            }

        } catch {
            print(error)
        }

        return checks
    }
}

class MyCheck: ParetoCheck {
    private var customCheck: CustomCheck

    init(check: CustomCheck) {
        customCheck = check
    }

    override var UUID: String {
        customCheck.id
    }

    override var TitleON: String {
        "\(customCheck.title) is passing"
    }

    override var TitleOFF: String {
        "\(customCheck.title) is failing"
    }

    override func checkPasses() -> Bool {
        return customCheck.passes()
    }

    override var infoURL: URL {
        let helpUrl = "https://paretosecurity.com/custom-check/?id=" + UUID + "&utm_source=" + AppInfo.utmSource
        if let docsUrl = customCheck.url {
            return URL(string: docsUrl) ?? URL(string: helpUrl)!
        }
        return URL(string: helpUrl)!
    }
}
