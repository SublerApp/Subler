//
//  ProgressViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 07/02/2018.
//

import Cocoa

protocol ProgressViewControllerDelegate : AnyObject {
    func cancelSave()
}

final class ProgressViewController: NSViewController {

    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var progressString: NSTextField!
    @IBOutlet var progressBar: NSProgressIndicator!

    weak var delegate: ProgressViewControllerDelegate?

    private var isIndeterminate: Bool = true

    override var nibName: NSNib.Name? {
        return "ProgressViewController"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        progressBar.isIndeterminate = true
    }

    var progress: Double {
        set (progress) {
            if isIndeterminate {
                isIndeterminate = false
                progressBar.isIndeterminate = false
            }
            progressBar.doubleValue = progress
        }
        get {
            return progressBar.doubleValue
        }
    }

    var progressTitle: String {
        set (progressTitle) {
            progressString.stringValue = progressTitle
        }
        get {
            return progressString.stringValue
        }
    }

    @IBAction func cancel(_ sender: Any) {
        delegate?.cancelSave()
        cancelButton.isEnabled = false
    }
}
