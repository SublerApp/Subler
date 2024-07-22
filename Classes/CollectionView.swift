//
//  CollectionView.swift
//  Subler
//
//  Created by Damiano Galassi on 29/06/24.
//

import Cocoa

@objc protocol CollectionViewDelegate: NSCollectionViewDelegate {
    @MainActor @objc optional func collectionViewDelete(in collectionView: NSCollectionView)
    @MainActor @objc optional func collectionViewCopy(in collectionView: NSCollectionView)
    @MainActor @objc optional func collectionViewCut(in collectionView: NSCollectionView)
    @MainActor @objc optional func collectionViewPaste(to collectionView: NSCollectionView)
}

class CollectionView: NSCollectionView, NSUserInterfaceValidations {

    var pasteboardTypes: [NSPasteboard.PasteboardType]
    var pasteboardHasSupportedType: Bool {
        get {
            // Has the pasteboard got a type we support?
            let pb = NSPasteboard.general
            let bestType = pb.availableType(from: pasteboardTypes)
            return bestType != nil
        }
    }

    private var expandedDelegate: CollectionViewDelegate? {
        get {
            return delegate as? CollectionViewDelegate
        }
    }

    override init(frame frameRect: NSRect) {
        pasteboardTypes = Array()
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        pasteboardTypes = Array()
        super.init(coder: coder)
    }

    private var isSelected: Bool {
        get {
            selectionIndexPaths.isEmpty == false
        }
    }

    private var isSelectionEmpty: Bool {
        get {
            selectionIndexPaths.isEmpty == true
        }
    }

    override func keyDown(with event: NSEvent) {
        guard let key = event.charactersIgnoringModifiers?.utf16.first else { super.keyDown(with: event); return }

        if (key == NSDeleteCharacter || key == NSDeleteFunctionKey) && implements(selector: #selector(CollectionViewDelegate.collectionViewDelete(in:))) {
            if isSelectionEmpty {
                __NSBeep()
            } else {
                expandedDelegate?.collectionViewDelete!(in: self)
            }
        }
        else if key == 27 && isSelected {
            deselectAll(self)
        }
        else if self.isSelectionEmpty && (key == NSUpArrowFunctionKey || key == NSDownArrowFunctionKey) {
            let indexPathSet = Set([IndexPath(item: 0, section: 0)])
            animator().selectItems(at: indexPathSet, scrollPosition: .bottom)
            delegate?.collectionView?(self, didSelectItemsAt: indexPathSet)
        }
        else if self.isSelectionEmpty && (key == NSRightArrowFunctionKey || key == NSLeftArrowFunctionKey) {
            self.window?.windowController?.keyDown(with: event)
        }
        else {
            super.keyDown(with: event)
        }
    }

    private func implements(selector: Selector) -> Bool {
        if let implemented = expandedDelegate?.responds(to: selector),
           implemented == true {
            return true
        }
        return false
    }

    @IBAction func delete(_ sender: Any?) {
        if isSelected && implements(selector: #selector(CollectionViewDelegate.collectionViewDelete(in:))) {
            expandedDelegate?.collectionViewDelete!(in: self)
        }
    }

    @IBAction func copy(_ sender: Any?) {
        if isSelected && implements(selector: #selector(CollectionViewDelegate.collectionViewCopy(in:))) {
            expandedDelegate?.collectionViewCopy!(in: self)
        }
    }

    @IBAction func cut(_ sender: Any?) {
        if isSelected && implements(selector: #selector(CollectionViewDelegate.collectionViewCut(in:))) {
            expandedDelegate?.collectionViewCut!(in: self)
        }
    }

    @IBAction func paste(_ sender: Any?) {
        if implements(selector: #selector(CollectionViewDelegate.collectionViewPaste(to:))) {
            expandedDelegate?.collectionViewPaste!(to: self)
        }
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let action = item.action {
            switch action {
            case #selector(delete(_:)):
                if isSelectionEmpty || implements(selector: #selector(CollectionViewDelegate.collectionViewDelete(in:))) == false {
                    return false
                }
            case #selector(copy(_:)):
                if isSelectionEmpty || implements(selector: #selector(CollectionViewDelegate.collectionViewCopy(in:))) == false {
                    return false
                }
            case #selector(cut(_:)):
                if isSelectionEmpty || implements(selector: #selector(CollectionViewDelegate.collectionViewCut(in:))) == false {
                    return false
                }
            case #selector(paste(_:)):
                if pasteboardHasSupportedType == false || implements(selector:  #selector(CollectionViewDelegate.collectionViewPaste(to:))) == false {
                    return false
                }
            default:
                break
            }
        }
        return true
    }

}
