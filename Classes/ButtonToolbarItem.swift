//
//  ButtonToolbarItem.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

class ButtonToolbarItem : NSToolbarItem {

    override func validate() {
        if let target = target {
            isEnabled = target.validateToolbarItem(self)
        }
    }

    override var menuFormRepresentation: NSMenuItem? {
        get {
            let menuItem = NSMenuItem(title: label, action: action, keyEquivalent: "")
            menuItem.target = target
            menuItem.isEnabled = target?.validateToolbarItem(self) ?? false
            return menuItem
        }
        set (menuItem) {
            super.menuFormRepresentation = menuItem
        }
    }
}
