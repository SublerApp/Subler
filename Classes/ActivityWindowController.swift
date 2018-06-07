//
//  ActivityWindowController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa
import MP42Foundation

class ActivityWindowController : NSWindowController, MP42Logging {

    @IBOutlet var logView: NSTextView!
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        super.init(window: nil)
        self.logger.delegate = self
        _ = self.window;
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var windowNibName: NSNib.Name? {
        return "SBActivityWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    func write(toLog string: String) {
        DispatchQueue.main.async {
            let attrString = NSAttributedString(string: string)
            self.logView.textStorage?.append(attrString)
        }
    }

    @IBAction func clearLog(_ sender: Any) {
        logger.clear()
        if let textStorage = logView.textStorage {
            textStorage.deleteCharacters(in: NSMakeRange(0, textStorage.length))
        }
    }


}
