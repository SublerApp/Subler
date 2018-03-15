//
//  NSWindowAdditions.swift
//  Subler
//
//  Created by Damiano Galassi on 15/03/2018.
//

import Cocoa

extension NSWindow {
    func endEditing() -> Bool {
        var success = false
        var selectedRange = NSRange()
        var responder: AnyObject? = self.firstResponder

        // If we're dealing with the field editor, the real first responder is
        // its delegate.
        if let parentResponder = responder as? NSTextView, parentResponder.isFieldEditor {
            responder = ((parentResponder.delegate as? NSResponder) != nil) ? parentResponder.delegate : nil
            if let textField = responder as? NSTextField {
                selectedRange = textField.currentEditor()?.selectedRange ?? NSRange()
            }
        }

        success = self.makeFirstResponder(nil)

        // Return first responder status.
        if success, let nextResponder = responder as? NSResponder {
            self.makeFirstResponder(nextResponder)
            if let textField = nextResponder as? NSTextField {
                textField.currentEditor()?.selectedRange = selectedRange
            }
        }

        return success
    }
}
