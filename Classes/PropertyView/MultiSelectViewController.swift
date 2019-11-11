//
//  MultiSelectViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

final class MultiSelectViewController : PropertyView {

    var numberOfTracks: UInt = 0 {
        didSet {
            reloadUI()
        }
    }

    @IBOutlet var label: NSTextField!

    override var nibName: NSNib.Name? {
        return "MultiSelectView"
    }

    init(numberOfTracks: UInt) {
        self.numberOfTracks = numberOfTracks
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
