//
//  Color.swift
//  Color
//
//  Created by Janez Troha on 18/09/2021.
//

import Foundation
import SwiftUI

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
public extension SwiftUI.Color {
    init(hex: Int, alpha: Double = 1) {
        let components = (
            R: Double((hex >> 16) & 0xFF) / 255,
            G: Double((hex >> 08) & 0xFF) / 255,
            B: Double((hex >> 00) & 0xFF) / 255
        )

        self.init(
            .sRGB,
            red: components.R,
            green: components.G,
            blue: components.B,
            opacity: alpha
        )
    }
}

public extension Color {
    static func dynamic(dark: Int, light: Int) -> Color {
        let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        return isDark ? Color(hex: dark) : Color(hex: light)
    }

    // MARK: - App Colors

    static var mainColor = Color(hex: 0x4C84E2)

    // MARK: - Text Colors

    static let placeholderText = Color(NSColor.placeholderTextColor)

    // MARK: - Label Colors

    static let label = Color(NSColor.labelColor)
    static let secondaryLabel = Color(NSColor.secondaryLabelColor)
    static let tertiaryLabel = Color(NSColor.tertiaryLabelColor)
    static let quaternaryLabel = Color(NSColor.quaternaryLabelColor)

    // MARK: - Gray Colors

    static let systemGray = Color(NSColor.systemGray)
    static let systemGray2 = Color.dynamic(dark: 0x636366, light: 0xAEAEB2)
    static let systemGray3 = Color.dynamic(dark: 0x48484A, light: 0xC7C7CC)
    static let systemGray4 = Color.dynamic(dark: 0x3A3A3C, light: 0xD1D1D6)
    static let systemGray5 = Color.dynamic(dark: 0x2C2C2E, light: 0xE5E5EA)
    static let systemGray6 = Color.dynamic(dark: 0x1C1C1E, light: 0xF2F2F7)

    // MARK: - Other Colors

    static let separator = Color(NSColor.separatorColor)
    static let link = Color(NSColor.linkColor)

    // MARK: System Colors

    static let systemBlue = Color(NSColor.systemBlue)
    static let systemPurple = Color(NSColor.systemPurple)
    static let systemGreen = Color(NSColor.systemGreen)
    static let systemYellow = Color(NSColor.systemYellow)
    static let systemOrange = Color(NSColor.systemOrange)
    static let systemPink = Color(NSColor.systemPink)
    static let systemRed = Color(NSColor.systemRed)
    static let systemTeal = Color(NSColor.systemTeal)
    static let systemIndigo = Color(NSColor.systemIndigo)
}
