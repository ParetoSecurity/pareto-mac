//
//  FreeView.swift
//  FreeView
//
//  Created by Janez Troha on 09/09/2021.
//

import SwiftUI

struct FreeView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            VisualEffectView(material: NSVisualEffectView.Material.popover, blendingMode: NSVisualEffectView.BlendingMode.behindWindow)
            VStack(alignment: .leading, spacing: 5) {
                Text("You are running the free version of the app. Please consider purchasing the Personal lifetime license for unlimited devices!")
                Spacer()
                Text("This nag screen goes away with the purchase. :)")
                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                }.buttonStyle(BorderedButtonStyle()).keyboardShortcut(.defaultAction)
            }.frame(width: 320, height: 120, alignment: .center).padding(20)
        }
    }
}

struct FreeView_Previews: PreviewProvider {
    static var previews: some View {
        FreeView(onContinue: {})
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = NSVisualEffectView.State.active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context _: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

class FloatingPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        // Not sure if .titled does affect anything here. Kept it because I think it might help with accessibility but I did not test that.
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView], backing: backing, defer: flag)

        // Set this if you want the panel to remember its size/position
        //        self.setFrameAutosaveName("a unique name")

        // Allow the pannel to be on top of almost all other windows
        isFloatingPanel = true
        level = .floating

        // Allow the pannel to appear in a fullscreen space
        collectionBehavior.insert(.fullScreenAuxiliary)

        // While we may set a title for the window, don't show it
        titlebarAppearsTransparent = true

        // Since there is no titlebar make the window moveable by click-dragging on the background
        isMovableByWindowBackground = true

        // Keep the panel around after closing since I expect the user to open/close it often
        isReleasedWhenClosed = false

        // Activate this if you want the window to hide once it is no longer focused
        //        self.hidesOnDeactivate = true

        // Hide the traffic icons (standard close, minimize, maximize buttons)
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        title = "Pareto Security"

        // Center doesn't place it in the absolute center, see the documentation for more details
        center()
        styleMask.remove(.resizable)
        // Shows the panel and makes it active
        orderFront(nil)
        makeKey()
    }

    // `canBecomeKey` and `canBecomeMain` are required so that text inputs inside the panel can receive focus
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}
