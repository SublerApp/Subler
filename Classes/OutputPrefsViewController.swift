//
//  OutputPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 30/11/2017.
//

import Cocoa

class OutputPrefsViewController: NSViewController, NSTokenFieldDelegate {

    @IBOutlet var movieField: NSTokenField!
    @IBOutlet var tvShowField: NSTokenField!

    var moviePopover: NSPopover?
    var tvShowPopover: NSPopover?

    let separators: CharacterSet

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "OutputPrefsViewController")
    }

    init() {
        self.separators = CharacterSet(charactersIn: "{}")
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Filename", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        movieField.tokenizingCharacterSet = CharacterSet(charactersIn: "%")
        tvShowField.tokenizingCharacterSet = CharacterSet(charactersIn: "%")
    }

    // MARK: Actions

    @IBAction func showMovieTokens(_ sender: NSView) {
        if let popover = tvShowPopover {
            popover.close()
            tvShowPopover = nil
        }
        if let popover = moviePopover {
            popover.close()
            moviePopover = nil
        }
        else {
            moviePopover = showTokensPopover(tokens: MP42Metadata.writableMetadata, view: sender)
        }
    }

    @IBAction func showTvShowTokens(_ sender: NSView) {
        if let popover = moviePopover {
            popover.close()
            moviePopover = nil
        }
        if let popover = tvShowPopover {
            popover.close()
            tvShowPopover = nil
        }
        else {
            tvShowPopover = showTokensPopover(tokens: MP42Metadata.writableMetadata, view: sender)
        }
    }

    private func showTokensPopover(tokens: [String], view: NSView) -> NSPopover {
        let tokensController = TokensViewController(tokens: tokens)
        let p = NSPopover()
        p.contentViewController = tokensController
        p.show(relativeTo: view.bounds, of: view, preferredEdge: NSRectEdge.maxY)
        return p
    }

    // MARK: Format Token Field Delegate

    override func controlTextDidEndEditing(_ obj: Notification) {

    }

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

    func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
        // Disable whitespace-trimming
        return editingString
    }

//    func tokenField(_ tokenField: NSTokenField, completionsForSubstring substring: String, indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [Any]? {
//        matches = currentTokens.filter { $0.hasPrefix(substring) }
//        return matches
//
//    }

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
