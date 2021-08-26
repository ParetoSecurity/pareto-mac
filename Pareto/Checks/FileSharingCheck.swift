//
//  FileSharingCheck.swift
//  FileSharingCheck
//
//  Created by Janez Troha on 19/08/2021.
//

class FileSharingCheck: ParetoCheck {
    override var UUID: String {
        "b96524e0-850b-4bb8-abc7-517051b6c14e"
    }

    override var Title: String {
        "Sharing files is off"
    }

    override func checkPasses() -> Bool {
        return !isListening(withPort: 445)
    }
}
