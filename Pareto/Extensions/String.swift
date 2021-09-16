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
}
