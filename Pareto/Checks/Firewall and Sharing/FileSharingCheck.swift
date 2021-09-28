//
//  FileSharingCheck.swift
//  FileSharingCheck
//
//  Created by Janez Troha on 19/08/2021.
//

class FileSharingCheck: ParetoCheck {
    static let sharedInstance = FileSharingCheck()
    override var UUID: String {
        "b96524e0-850b-4bb8-abc7-517051b6c14e"
    }

    override var TitleON: String {
        "Sharing files is off"
    }

    override var TitleOFF: String {
        "Sharing files is on"
    }

    override func checkPasses() -> Bool {
        return isNotListening(withPort: 445)
    }
}
