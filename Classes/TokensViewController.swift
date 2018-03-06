//
//  TokensViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 01/12/2017.
//

import Cocoa

class TokensViewController: NSViewController, NSTokenFieldDelegate {

    @IBOutlet var tokenField: NSTokenField!
    let tokens: [Token]
    let separators: CharacterSet

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "TokensViewController")
    }

    init(tokens: [String]) {
        self.tokens = tokens.map { Token(text: "{\($0)}") }
        self.separators = CharacterSet(charactersIn: "{}")
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tokenField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
        tokenField.objectValue = tokens
    }

    // MARK: Format Token Field Delegate

    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
        if let token = representedObject as? Token {
            return localizedMetadataKeyName(token.text.trimmingCharacters(in: separators))
        }
        return representedObject as? String
    }

    func tokenField(_ tokenField: NSTokenField, styleForRepresentedObject representedObject: Any) -> NSTokenField.TokenStyle {
        if let token = representedObject as? Token {
            return token.isPlaceholder ? .rounded : .none
        }
        else {
            return .none
        }
    }

    func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
        return Token(text: editingString)
    }

    func tokenField(_ tokenField: NSTokenField, editingStringForRepresentedObject representedObject: Any) -> String? {
        if let token =  representedObject as? Token {
            return "/\(token.text)/"
        }
        return representedObject as? String
    }

    func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
        return tokens
    }

    func tokenField(_ tokenField: NSTokenField, writeRepresentedObjects objects: [Any], to pboard: NSPasteboard) -> Bool {
        if let tokens = objects as? [Token] {
            let string = tokens.reduce("", { "\($0)/\($1.text)" })
            pboard.setString(string, forType: NSPasteboard.PasteboardType.string)
            return true
        }
        return false
    }

}
