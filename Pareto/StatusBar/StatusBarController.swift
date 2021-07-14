//
//  StatusBarController.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import AppKit
import SwiftUI
import MenuBuilder

class StatusBarController: NSMenu, NSMenuDelegate  {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    
    required init(coder decoder: NSCoder) {
        statusBar = NSStatusBar.init()
        statusItem = statusBar.statusItem(withLength: 28.0)
        super.init(coder: decoder)
    }
    
    init(){
        statusBar = NSStatusBar.init()
        statusItem = statusBar.statusItem(withLength: 28.0)
        super.init(title: "Pareto")
        self.delegate = self
        if let statusBarButton = statusItem.button {
            statusBarButton.image = #imageLiteral(resourceName: "StatusBarIcon")
            statusBarButton.image?.size = NSSize(width: 18.0, height: 18.0)
            statusBarButton.image?.isTemplate = true
            statusBarButton.target = self
        }
        let menu = NSMenu {
            MenuItem("Network firewall active"){
                MenuItem("More Information").onSelect {}
                SeparatorItem()
                MenuItem("Remaining: 17h 15min")
                SeparatorItem()
                MenuItem("Snooze 1 hour").onSelect {}
                MenuItem("Snooze 1 day").onSelect {}
                MenuItem("Snooze 1 week").onSelect {}
                MenuItem("Disable").onSelect {}
            }
            MenuItem("MacOS is up-to-date"){
                MenuItem("More Information").onSelect {}
                SeparatorItem()
                MenuItem("Remaining: 17h 15min")
                SeparatorItem()
                MenuItem("Snooze 1 hour").onSelect {}
                MenuItem("Snooze 1 day").onSelect {}
                MenuItem("Snooze 1 week").onSelect {}
                MenuItem("Disable").onSelect {}
            }
            MenuItem("Automatic login disabled"){
                MenuItem("More Information").onSelect {}
                SeparatorItem()
                MenuItem("Remaining: 17h 15min")
                SeparatorItem()
                MenuItem("Snooze 1 hour").onSelect {}
                MenuItem("Snooze 1 day").onSelect {}
                MenuItem("Snooze 1 week").onSelect {}
                MenuItem("Disable").onSelect {}
            }
            MenuItem("Gatekeeper active"){
                MenuItem("More Information").onSelect {}
                SeparatorItem()
                MenuItem("Remaining: 17h 15min")
                SeparatorItem()
                MenuItem("Snooze 1 hour").onSelect {}
                MenuItem("Snooze 1 day").onSelect {}
                MenuItem("Snooze 1 week").onSelect {}
                MenuItem("Disable").onSelect {}
            }
            SeparatorItem()
            MenuItem("Preferences").shortcut("s").onSelect {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
            MenuItem("Quit Pareto App")
                .shortcut("q")
                .onSelect {
                    NSApplication.shared.terminate(self)
                    
                }
        }
        
        statusItem.menu = menu
    }
}
