//
//  Samba.swift
//  Samba
//
//  Created by Janez Troha on 18/08/2021.
//

import Foundation

class FileSharingCheck: ParetoCheck {
    override var UUID: String {
        "b96524e0-850b-4bb8-abc7-517051b6c14e"
    }

    override var Title: String {
        "File sharing is disabled"
    }

    override func checkPasses() -> Bool {
        return !isListening(withPort: 445)
    }
}
