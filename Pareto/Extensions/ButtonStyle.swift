//
//  ButtonStyle.swift
//  ButtonStyle
//
//  Created by Janez Troha on 19/09/2021.
//

import Foundation
import SwiftUI

struct HighlightButtonStyle: ButtonStyle {
    let hPadding: CGFloat
    let vPadding: CGFloat
    let cornerRadius: CGFloat
    let color: Color
    let font: Font

    init(
        h: CGFloat = 15,
        v: CGFloat = 12,
        cornerRadius: CGFloat = 4,
        color: Color,
        font: Font = .body
    ) {
        hPadding = h
        vPadding = v
        self.cornerRadius = cornerRadius
        self.color = color
        self.font = font
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .contentShape(Rectangle())
            .font(font)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(configuration.isPressed ? Color.separator : color))
            .cornerRadius(cornerRadius)
    }
}
