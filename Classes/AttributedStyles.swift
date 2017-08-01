//
//  AttributedStyles.swift
//  Subler
//
//  Created by Damiano Galassi on 01/08/2017.
//

import Cocoa

// MARK: - Attributed styles

private let detailBoldMonospacedAttr = { () -> [NSAttributedStringKey : Any] in
    let ps = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    ps.headIndent = -10.0
    ps.alignment = NSTextAlignment.right

    if #available(macOS 10.11, *) {
        return [NSAttributedStringKey.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize,
                                                                             weight: NSFont.Weight.bold),
                NSAttributedStringKey.paragraphStyle: ps,
                NSAttributedStringKey.foregroundColor: NSColor.gray]
    }
    else {
        return [NSAttributedStringKey.font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize),
                NSAttributedStringKey.paragraphStyle: ps,
                NSAttributedStringKey.foregroundColor: NSColor.gray]
    }
}()

private let detailBoldAttr = { () -> [NSAttributedStringKey : Any] in
    let ps = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    ps.headIndent = -10.0
    ps.alignment = NSTextAlignment.left

    if #available(macOS 10.11, *) {
        return [NSAttributedStringKey.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize,
                                                                             weight: NSFont.Weight.bold),
                NSAttributedStringKey.paragraphStyle: ps,
                NSAttributedStringKey.foregroundColor: NSColor.gray]
    }
    else {
        return [NSAttributedStringKey.font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize),
                NSAttributedStringKey.paragraphStyle: ps,
                NSAttributedStringKey.foregroundColor: NSColor.gray]
    }
}()

private let detailMonospacedAttr = { () -> [NSAttributedStringKey : Any] in
    let ps = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    ps.headIndent = -10.0
    ps.alignment = NSTextAlignment.right

    if #available(macOS 10.11, *) {
        return [NSAttributedStringKey.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize,
                                                                             weight: NSFont.Weight.regular),
                NSAttributedStringKey.paragraphStyle: ps]
    }
    else {
        return [NSAttributedStringKey.font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize),
                NSAttributedStringKey.paragraphStyle: ps]
    }
}()

extension String {

    func boldAttributedString() -> NSAttributedString {
        return NSAttributedString(string: self, attributes: detailBoldAttr)
    }

    func boldMonospacedAttributedString() -> NSAttributedString {
        return NSAttributedString(string: self, attributes: detailBoldMonospacedAttr)
    }

    func monospacedAttributedString() -> NSAttributedString {
        return NSAttributedString(string: self, attributes: detailMonospacedAttr)
    }

}
