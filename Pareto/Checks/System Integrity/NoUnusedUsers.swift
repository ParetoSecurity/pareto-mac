//
//  Firewall.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

class NoUnusedUsers: ParetoCheck {
    static let sharedInstance = NoUnusedUsers()
    override var UUID: String {
        "018cca4b-bedc-7794-a45d-118b60424017"
    }

    override var TitleON: String {
        "No unrequired user accounts are present"
    }

    override var TitleOFF: String {
        "Unrequired user accounts are present(" + accounts.joined(separator: ",") + ")"
    }
    
    var accounts: [String] {
        let output = runCMD(app: "/usr/bin/dscl", args: [".", "-list", "/Users"]).components(separatedBy: "\n")
        let local = output.filter { u in
            return !u.hasPrefix("_") && u.count > 1 && u != "root" && u != "nobody" && u != "daemon"
        }
        return local
    }
    
    override func checkPasses() -> Bool {
        return accounts.count == 1
    }
}
