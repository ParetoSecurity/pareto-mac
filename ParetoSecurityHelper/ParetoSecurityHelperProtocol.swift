//
//  ParetoSecurityHelperProtocol.swift
//  ParetoSecurityHelper
//
//  Created by Janez Troha on 23. 5. 25.
//

import Foundation

@objc(ParetoSecurityHelperProtocol)
protocol ParetoSecurityHelperProtocol {
    func isFirewallEnabled(with reply: @escaping (String) -> Void)
    func isFirewallStealthEnabled(with reply: @escaping (String) -> Void)
}
