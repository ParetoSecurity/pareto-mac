//
//  URL.swift
//  URL
//
//  Created by Janez Troha on 10/09/2021.
//

import Foundation

extension URL {
    func queryParams() -> [String: String] {
        let queryItems = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems
        let queryTuples: [(String, String)] = queryItems?.compactMap {
            guard let value = $0.value else { return nil }
            return ($0.name, value)
        } ?? []
        return Dictionary(uniqueKeysWithValues: queryTuples)
    }
}
