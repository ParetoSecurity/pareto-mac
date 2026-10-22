//
//  Trim.swift
//  Pareto Security
//
//  Created by Janez Troha on 22. 7. 24.
//

extension String {
    func trim() -> String {
        replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\t", with: "")
    }
}
