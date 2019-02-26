//
//  AttributedStyles.swift
//  Subler
//
//  Created by Damiano Galassi on 01/08/2017.
//

import Cocoa

// MARK: - Attributed styles

private func monospaceAttributes(size: CGFloat, aligment: NSTextAlignment, headIndent: CGFloat = -10.0, firstLineHeadIndent: CGFloat = 0, bold: Bool, color: NSColor = NSColor.secondaryLabelColor) -> [NSAttributedString.Key : Any]  {
    let ps = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    ps.firstLineHeadIndent = firstLineHeadIndent
    ps.headIndent = headIndent
    ps.alignment = aligment
    
    return [NSAttributedString.Key.font: NSFont.monospacedDigitSystemFont(ofSize: size,
                                                                            weight: bold ? NSFont.Weight.bold : NSFont.Weight.regular),
            NSAttributedString.Key.paragraphStyle: ps,
            NSAttributedString.Key.foregroundColor: color]
}

private let detailBoldMonospacedAttr = { () -> [NSAttributedString.Key : Any] in
    return monospaceAttributes(size: NSFont.smallSystemFontSize, aligment: NSTextAlignment.right, bold: true)
}()

private let detailBoldAttr = { () -> [NSAttributedString.Key : Any] in
    return monospaceAttributes(size: NSFont.smallSystemFontSize, aligment: NSTextAlignment.left, bold: true)
}()

private let detailMonospacedAttr = { () -> [NSAttributedString.Key : Any] in
    return monospaceAttributes(size: NSFont.smallSystemFontSize, aligment: NSTextAlignment.right, bold: false)
}()

private let monospacedAttr = { () -> [NSAttributedString.Key : Any] in
    return monospaceAttributes(size: NSFont.systemFontSize, aligment: NSTextAlignment.right, bold: false, color: NSColor.controlTextColor)
}()

private let groupRowAttr = { () -> [NSAttributedString.Key : Any] in
    return monospaceAttributes(size: NSFont.systemFontSize, aligment: NSTextAlignment.left, firstLineHeadIndent: 24, bold: true)
}()

extension String {

    func boldAttributedString() -> NSAttributedString {
        return NSAttributedString(string: self, attributes: detailBoldAttr)
    }

    func boldMonospacedAttributedString() -> NSAttributedString {
        return NSAttributedString(string: self, attributes: detailBoldMonospacedAttr)
    }

    func smallMonospacedAttributedString() -> NSAttributedString {
        return NSAttributedString(string: self, attributes: detailMonospacedAttr)
    }

    func monospacedAttributedString() -> NSAttributedString {
        return NSAttributedString(string: self, attributes: monospacedAttr)
    }
    
    func groupAttributedString() -> NSAttributedString {
       return NSAttributedString(string: self, attributes: groupRowAttr)
    }

}
