//
//  CheckBoxCellView.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

final class CheckBoxCellView : NSTableCellView, ExpandedTableViewCellActionable {
    @IBOutlet var checkboxButton: NSButton!

    func performAction() {
        self.checkboxButton.performClick(self)
    }
}
