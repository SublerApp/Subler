//
//  PrefsWindow.swift
//  Subler
//
//  Created by Damiano Galassi on 06/02/2018.
//

import Cocoa

class PrefsWindow: NSWindow {

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(NSWindow.toggleToolbarShown(_:)) {
            return false
        }
        return super.validateUserInterfaceItem(item)
    }

}
