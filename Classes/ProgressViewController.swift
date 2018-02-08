//
//  ProgressViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 07/02/2018.
//

import Cocoa

protocol ProgressViewControllerDelegate : AnyObject {
    func cancel()
}

class ProgressViewController: NSViewController {

    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var progressString: NSTextField!
    @IBOutlet var progressBar: NSProgressIndicator!

    weak var delegate: ProgressViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func cancel(_ sender: Any) {
        delegate?.cancel()
        cancelButton.isEnabled = false
    }
}
