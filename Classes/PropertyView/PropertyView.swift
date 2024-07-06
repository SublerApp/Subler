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

    func selectTabViewItem(at index: Int) {
        tabView?.selectTabViewItem(at: index)
    }

    func selectedViewIndex() -> Int {
        var index = NSNotFound
        if let item = tabView?.selectedTabViewItem {
            index = tabView?.indexOfTabViewItem(item) ?? NSNotFound
        }
        return index
    }
}
