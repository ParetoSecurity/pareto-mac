//
//  StatusBarIcon.swift
//  Pareto Security
//
//  Created by Janez Troha on 20/12/2021.
//

import AppKit
import Defaults
import SwiftUI

enum StatusBarState: String {
    case initial = "Icon"
    case idle = "IconGray"
    case warning = "IconOrange"
    case allOk = "IconGreen"
}

class StatusBarModel: ObservableObject {
    // Default to a known-good asset with vector variants
    @Published var state = StatusBarState.idle
    @Published var isRunning = false
    // Bump to force menu refresh re-render when checks finish
    @Published var refreshNonce: Int = 0
}

struct StatusBarIcon: View {
    @ObservedObject var statusBarModel: StatusBarModel

    // Load by name and allow template if the asset supports it
    private var nsIcon: NSImage? {
        // Try to load by current state name, fall back to gray
        if let img = NSImage(named: statusBarModel.state.rawValue) {
            return img
        }
        return NSImage(named: StatusBarState.initial.rawValue)
    }

    private var overlayColor: Color {
        // While running, always show neutral gray regardless of last state
        if statusBarModel.isRunning {
            return .gray
        }
        switch statusBarModel.state {
        case .allOk:
            return Color(nsColor: Defaults.OKColor())
        case .warning:
            return Color(nsColor: Defaults.FailColor())
        case .idle, .initial:
            return .gray
        }
    }

    // Provide an intrinsically sized NSImage to avoid hosts ignoring SwiftUI frames.
    private func sizedIcon(from img: NSImage, side: CGFloat) -> NSImage {
        let targetSize = NSSize(width: side, height: side)
        let newImage = NSImage(size: targetSize)
        // Ensure we keep original colors (not template-tinted white in menu bar)
        newImage.isTemplate = false
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let destRect = NSRect(origin: .zero, size: targetSize)
        img.draw(in: destRect)
        newImage.unlockFocus()
        return newImage
    }

    var body: some View {
        // Center inside the status bar button area
        ZStack(alignment: .bottomLeading) {
            // Keep transparent background; only show the icon
            if let img = nsIcon {
                let side = NSStatusBar.system.thickness
                let preSized = sizedIcon(from: img, side: side)

                Image(nsImage: preSized)
                    .renderingMode(.original)
                    .interpolation(.high)
                    .antialiased(true)
                    .accessibilityHidden(true)
            }

            // Overlay: spinner while running, otherwise status dot
            let side = NSStatusBar.system.thickness
            // Make the overlay small relative to the bar size; keep readable
            let overlaySide = max(10, floor(side * 0.55))
            // Small colored status dot in the bottom-left corner
            Circle()
                .fill(overlayColor)
                .frame(width: overlaySide, height: overlaySide)
                .padding(2)
                .accessibilityHidden(true)
        }
        // Force refresh when running state or nonce changes
        .id(statusBarModel.refreshNonce ^ (statusBarModel.isRunning ? 1 : 0))
    }
}
