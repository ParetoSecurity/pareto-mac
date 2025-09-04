//
//  CenteredContent.swift
//  Pareto
//
//  A tiny helper to horizontally center settings content
//  within the available window width while preserving
//  native List/Form behavior.
//

import SwiftUI

extension View {
    func centered(maxContentWidth: CGFloat = 680) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            self
                .frame(maxWidth: maxContentWidth, alignment: .center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

