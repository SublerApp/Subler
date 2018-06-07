//
//  AdvancedPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 06/02/2018.
//

import Cocoa

class AdvancedPrefsViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Advanced", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var nibName: NSNib.Name? {
        return "AdvancedPrefsViewController"
    }

}
