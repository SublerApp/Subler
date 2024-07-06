//
//  TokenFieldCell.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

final class TokenFieldCell : NSTokenFieldCell {

    private var originalBackgroundStyle: NSView.BackgroundStyle = NSView.BackgroundStyle.normal

    override var backgroundStyle: NSView.BackgroundStyle {
        get {
            return super.backgroundStyle
        }
        set (newBackgroundStyle) {
            super.backgroundStyle = newBackgroundStyle
            if newBackgroundStyle == NSView.BackgroundStyle.emphasized {
                textColor = NSColor.controlHighlightColor
            } else {
                textColor = NSColor.controlTextColor
            }
        }
    }

    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        originalBackgroundStyle = backgroundStyle
        backgroundStyle = NSView.BackgroundStyle.normal
        drawsBackground = true
        return super.setUpFieldEditorAttributes(textObj)
    }

    override func endEditing(_ textObj: NSText) {
        super.endEditing(textObj)
        drawsBackground = false
        backgroundStyle = originalBackgroundStyle
    }

}
