// Swift code here (new file suggestion)
// View+Centered.swift
import SwiftUI

public extension View {
    /// Centers content horizontally within its container and constrains the maximum width,
    /// which is useful for macOS settings-style forms and lists.
    func centered(maxWidth: CGFloat = 560, alignment: Alignment = .center) -> some View {
        HStack {
            Spacer(minLength: 0)
            self
                .frame(maxWidth: maxWidth, alignment: alignment)
            Spacer(minLength: 0)
        }
    }
}
