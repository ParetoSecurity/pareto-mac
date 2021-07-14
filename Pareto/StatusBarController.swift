//
//  StatusBarController.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import AppKit

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
    }
}
