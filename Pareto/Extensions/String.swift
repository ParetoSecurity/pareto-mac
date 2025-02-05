//
//  String.swift
//  String
//
//  Created by Janez Troha on 16/09/2021.
//

import Foundation

extension String {
    var isUUID: Bool {
        return UUID(uuidString: self) != nil
    }
    /// Escapes the string for safe shell usage.
    func shellEscaped() -> String {
        // Replace any single quote with an escaped version
        let escaped = self.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
