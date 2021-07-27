import AppKit
import Combine
import Foundation
import os.log
import SwiftUI

extension NSImage {
    static func SF(name: String) -> NSImage {
        let icon = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        icon.isTemplate = true
        return icon
    }

    func tint(color: NSColor) -> NSImage {
        if isTemplate == false {
            return self
        }

        guard let image = copy() as? NSImage else {
            return self
        }

        image.lockFocus()

        color.set()

        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceIn)

        image.unlockFocus()
        image.isTemplate = false

        return image
    }
}
