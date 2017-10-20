//
//  ComboBoxCell.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

class ComboBoxCell : NSComboBoxCell {

    private var originalBackgroundStyle: NSView.BackgroundStyle = NSView.BackgroundStyle.light

    override var backgroundStyle: NSView.BackgroundStyle {
        get {
            return super.backgroundStyle
        }
        set (newBackgroundStyle) {
            super.backgroundStyle = newBackgroundStyle
            if newBackgroundStyle == NSView.BackgroundStyle.dark {
                textColor = NSColor.controlHighlightColor
            } else {
                textColor = NSColor.controlTextColor
            }
        }
    }

    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        originalBackgroundStyle = backgroundStyle
        backgroundStyle = NSView.BackgroundStyle.light
        drawsBackground = true
        return super.setUpFieldEditorAttributes(textObj)
    }

    override func endEditing(_ textObj: NSText) {
        super.endEditing(textObj)
        drawsBackground = false
        backgroundStyle = originalBackgroundStyle
    }

}
