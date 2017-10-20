//
//  MultiSelectViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

class MultiSelectViewController : NSViewController {

    @objc var numberOfTracks: UInt = 0
    @IBOutlet var label: NSTextField!

    override func loadView() {
        super.loadView()

        if numberOfTracks == 1 {
            label.stringValue = NSLocalizedString("1 track selected", comment: "")
        } else {
            label.stringValue = String(format: NSLocalizedString("%lu tracks selected", comment: ""), numberOfTracks)
        }
    }
}
