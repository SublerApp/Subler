//
//  ActivityWindowController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa
import MP42Foundation

final class ActivityWindowController : NSWindowController, MP42Logging {

    @IBOutlet var logView: NSTextView!
    let logger: Logger
    private let storage: NSTextStorage
    private let attributes: [NSAttributedString.Key:Any]

    init(logger: Logger) {
        self.logger = logger
        self.storage = NSTextStorage()
        self.attributes = [NSAttributedString.Key.foregroundColor: NSColor.textColor]
        super.init(window: nil)
        self.logger.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var windowNibName: NSNib.Name? {
        return "SBActivityWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        logView.layoutManager?.replaceTextStorage(storage)
    }

    func write(toLog string: String) {
        DispatchQueue.main.async {
            let attrString = NSAttributedString(string: string, attributes: self.attributes)
            self.storage.append(attrString)
        }
    }

    @IBAction func clearLog(_ sender: Any) {
        logger.clear()
        storage.deleteCharacters(in: NSMakeRange(0, storage.length))
    }


}
