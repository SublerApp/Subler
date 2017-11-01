//
//  AttributedStyles.swift
//  Subler
//
//  Created by Damiano Galassi on 01/08/2017.
//

import Cocoa

// MARK: - Attributed styles

private func monospaceAttributes(size: CGFloat, aligment: NSTextAlignment, headIndent: CGFloat = -10.0, firstLineHeadIndent: CGFloat = 0, bold: Bool) -> [NSAttributedStringKey : Any]  {
    let ps = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    ps.firstLineHeadIndent = firstLineHeadIndent
    ps.headIndent = headIndent
    ps.alignment = aligment
    
    if #available(macOS 10.11, *) {
        return [NSAttributedStringKey.font: NSFont.monospacedDigitSystemFont(ofSize: size,
                                                                             weight: bold ? NSFont.Weight.bold : NSFont.Weight.regular),
                NSAttributedStringKey.paragraphStyle: ps,
                NSAttributedStringKey.foregroundColor: NSColor.gray]
    }
    else {
        return [NSAttributedStringKey.font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
                NSAttributedStringKey.paragraphStyle: ps,
                NSAttributedStringKey.foregroundColor: NSColor.gray]
    }
}

private let detailBoldMonospacedAttr = { () -> [NSAttributedStringKey : Any] in
    return monospaceAttributes(size: NSFont.smallSystemFontSize, aligment: NSTextAlignment.right, bold: true)
}()

private let detailBoldAttr = { () -> [NSAttributedStringKey : Any] in
    return monospaceAttributes(size: NSFont.smallSystemFontSize, aligment: NSTextAlignment.left, bold: true)
}()

private let detailMonospacedAttr = { () -> [NSAttributedStringKey : Any] in
    return monospaceAttributes(size: NSFont.smallSystemFontSize, aligment: NSTextAlignment.right, bold: false)
}()

private let groupRowAttr = { () -> [NSAttributedStringKey : Any] in
    return monospaceAttributes(size: NSFont.systemFontSize, aligment: NSTextAlignment.left, firstLineHeadIndent: 24, bold: true)
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
    
    func groupAttributedString() -> NSAttributedString {
       return NSAttributedString(string: self, attributes: groupRowAttr)
    }

}
