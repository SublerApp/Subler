//
//  ExceptionAlertController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

class ExceptionAlertController: NSWindowController {

    @IBOutlet var exceptionMessageTextField: NSTextField!
    @IBOutlet var exceptionBacktraceTextView: NSTextView!

    private let exceptionMessage: String
    private let exceptionBacktrace: NSAttributedString

    @objc init(exceptionMessage: String, exceptionBacktrace: NSAttributedString) {
        self.exceptionMessage = exceptionMessage
        self.exceptionBacktrace = exceptionBacktrace
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "ExceptionAlert")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        exceptionMessageTextField.stringValue = exceptionMessage
        exceptionBacktraceTextView.textStorage?.append(exceptionBacktrace)
    }

    @IBAction func btnCrashClicked(_ sender: Any) {
        window?.orderOut(self)
        NSApp.stopModal(withCode: NSApplication.ModalResponse.stop)
    }

    @IBAction func btnContinueClicked(_ sender: Any) {
        window?.orderOut(self)
        NSApp.stopModal(withCode: NSApplication.ModalResponse.continue)
    }

    @objc func runModal() -> NSApplication.ModalResponse {
        return NSApp.runModal(for: window!)
    }

}
