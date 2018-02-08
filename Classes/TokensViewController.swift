//
//  TokensViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 01/12/2017.
//

import Cocoa

class TokensViewController: NSViewController, NSTokenFieldDelegate {

    @IBOutlet var tokenField: NSTokenField!
    let tokens: [String]
    let separators: CharacterSet

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "TokensViewController")
    }

    init(tokens: [String]) {
        self.tokens = tokens
        self.separators = CharacterSet(charactersIn: "{}")
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tokenField.tokenizingCharacterSet = CharacterSet(charactersIn: "%")
        tokenField.stringValue = tokens.reduce("", { "\($0)%{\($1)}" })
    }

    // MARK: Format Token Field Delegate

    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
        if let stringValue = representedObject as? String, stringValue.hasPrefix("{") {
            return localizedMetadataKeyName(stringValue.trimmingCharacters(in: separators))
        }
        return representedObject as? String
    }

    func tokenField(_ tokenField: NSTokenField, styleForRepresentedObject representedObject: Any) -> NSTokenField.TokenStyle {
        if let stringValue = representedObject as? String, stringValue.hasPrefix("{") {
            return .rounded
        }
        else {
            return .none
        }
    }

    func tokenField(_ tokenField: NSTokenField, editingStringForRepresentedObject representedObject: Any) -> String? {
        if let stringValue = representedObject as? String, stringValue.hasPrefix("{") {
            return "%\(stringValue)%"
        }
        return representedObject as? String
    }

    func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
        return tokens
    }

    func tokenField(_ tokenField: NSTokenField, writeRepresentedObjects objects: [Any], to pboard: NSPasteboard) -> Bool {
        if let strings = objects as? [String] {
            let string = strings.reduce("", { "\($0)%\($1)" })
            pboard.setString(string, forType: NSPasteboard.PasteboardType.string)
            return true
        }
        return false
    }

}
