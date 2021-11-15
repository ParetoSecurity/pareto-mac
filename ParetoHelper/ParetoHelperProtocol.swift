//
//  ParetoHelperProtocol.swift
//  ParetoHelper
//
//  Created by Janez Troha on 15/11/2021.
//

import Foundation

@objc(HelperProtocol)
protocol HelperProtocol {
    func getVersion(completion: @escaping (String) -> Void)
    func runCommandLs(withPath: String, completion: @escaping (NSNumber) -> Void)
    func runCommandLs(withPath: String, authData: NSData?, completion: @escaping (NSNumber) -> Void)
}
