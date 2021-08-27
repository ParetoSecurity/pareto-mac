//
//  NSWindow.swift
//  NSWindow
//
//  Created by Janez Troha on 30/08/2021.
//

import Foundation
import SwiftUI

extension NSWindow {
    static func createStandardWindow(withTitle title: String,
                                     width: CGFloat = 800, height: CGFloat = 600) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.center()
        window.title = title
        return window
    }
}
