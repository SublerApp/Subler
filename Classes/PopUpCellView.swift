//
//  PopUpCellView.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

final class PopUpCellView : NSTableCellView, ExpandedTableViewCellActionable {
    @IBOutlet var popUpButton: NSPopUpButton!

    func performAction() {
        self.popUpButton.performClick(self)
    }
}
