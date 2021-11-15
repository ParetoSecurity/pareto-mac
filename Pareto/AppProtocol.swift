//
//  AppProtocol.swift
//  ParetoHelper
//
//  Created by Janez Troha on 15/11/2021.
//

import Foundation

@objc(AppProtocol)
protocol AppProtocol {
    func log(stdOut: String)
    func log(stdErr: String)
}
