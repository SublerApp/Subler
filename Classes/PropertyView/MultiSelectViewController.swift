//
//  MultiSelectViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

class MultiSelectViewController : NSViewController {

    var numberOfTracks: UInt = 0
    @IBOutlet var label: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadUI()
    }

    func reloadUI() {
        if numberOfTracks == 1 {
            label.stringValue = NSLocalizedString("1 track selected", comment: "")
        } else {
            label.stringValue = String.localizedStringWithFormat(NSLocalizedString("%lu tracks selected", comment: ""), numberOfTracks)
        }
    }
}
