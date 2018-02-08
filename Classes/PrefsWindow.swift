//
//  PrefsWindow.swift
//  Subler
//
//  Created by Damiano Galassi on 06/02/2018.
//

import Cocoa

class PrefsWindow: NSWindow {

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(NSWindow.toggleToolbarShown(_:)) {
            return false
        }
        return super.validateMenuItem(menuItem)
    }

}
