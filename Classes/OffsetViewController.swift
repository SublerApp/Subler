//
//  OffsetViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 06/02/2018.
//

import Cocoa
import MP42Foundation

final class OffsetViewController: NSViewController {

    private let doc: Document
    private let track: MP42Track

    @IBOutlet var offsetField: NSTextField!
    
    init(doc: Document, track: MP42Track) {
        self.doc = doc
        self.track = track
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var nibName: NSNib.Name? {
        return "OffsetViewController"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        offsetField.doubleValue = track.startOffset
    }

    @IBAction func setOffset(_ sender: Any) {
        if track.startOffset != offsetField.doubleValue {
            track.startOffset = offsetField.doubleValue
            doc.updateChangeCount(.changeDone)
        }
        presentingViewController?.dismiss(self)
    }

    @IBAction func dismiss(_ sender: Any) {
        presentingViewController?.dismiss(self)
    }
}
