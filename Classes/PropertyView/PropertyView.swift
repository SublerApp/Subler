//
//  PropertyView.swift
//  Subler
//
//  Created by Damiano Galassi on 11/11/2019.
//

import Cocoa

class PropertyView : NSViewController {
    @IBOutlet var tabView: NSTabView?

    func navigate(direction: Int) {
        if direction == NSRightArrowFunctionKey {
            tabView?.selectNextTabViewItem(self)
        } else {
            tabView?.selectPreviousTabViewItem(self)
        }
    }
}
