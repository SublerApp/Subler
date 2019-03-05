//
//  ImageBrowserView.swift
//  Subler
//
//  Created by Damiano Galassi on 11/11/2017.
//

import Cocoa
import Quartz

@objc(SBImageBrowserViewDelegate) protocol ImageBrowserViewDelegate : NSObjectProtocol {
    @objc(pasteToImageBrowserView:) optional func paste(to imagebrowserview: ImageBrowserView)
}

@objc(SBImageBrowserView) final class ImageBrowserView : IKImageBrowserView, NSMenuItemValidation {

    @objc var pasteboardTypes: [NSPasteboard.PasteboardType]
    var pasteboardHasSupportedType: Bool {
        get {
            // has the pasteboard got a type we support?
            let pb = NSPasteboard.general
            let bestType = pb.availableType(from: pasteboardTypes)
            return bestType != nil
        }
    }

    private var expandedDelegate: ImageBrowserViewDelegate? {
        get {
            return delegate as? ImageBrowserViewDelegate
        }
    }

    override init(frame frameRect: NSRect) {
        pasteboardTypes = Array()
        super.init(frame: frameRect)
        updateBackgroundColor()
    }

    required init?(coder: NSCoder) {
        pasteboardTypes = Array()
        super.init(coder: coder)
        updateBackgroundColor()
    }

    override func viewDidChangeEffectiveAppearance() {
        updateBackgroundColor()
    }

    private func updateBackgroundColor() {
        if #available(OSX 10.14, *) {
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua]) == .darkAqua ? true : false
            if dark {
                setValue(NSColor.clear, forKey: IKImageBrowserBackgroundColorKey)
            } else {
                setValue(NSColor.white, forKey: IKImageBrowserBackgroundColorKey)
            }
        }
    }

    private func implements(selector: Selector) -> Bool {
        if let implemented = expandedDelegate?.responds(to: selector),
            implemented == true {
            return true
        }
        return false
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if let action = menuItem.action {
            switch action {
            case #selector(paste(_:)):
                if pasteboardHasSupportedType == false || implements(selector:  #selector(ExpandedTableViewDelegate.paste(to:))) == false {
                    return false
                }
            default:
                break
            }
        }
        return true
    }

    @IBAction func paste(_ sender: Any?) {
        if implements(selector: #selector(ImageBrowserViewDelegate.paste(to:))) {
            expandedDelegate?.paste!(to: self)
        }
    }

}
