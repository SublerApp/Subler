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

        movieField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
        tvShowField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")

        movieField.objectValue = UserDefaults.standard.tokenArray(forKey: "SBMovieFormatTokens")
        tvShowField.objectValue = UserDefaults.standard.tokenArray(forKey: "SBTVShowFormatTokens")
    }

    private func save() {
        UserDefaults.standard.set(movieField.objectValue as! [Token], forKey: "SBMovieFormatTokens")
        UserDefaults.standard.set(tvShowField.objectValue as! [Token], forKey: "SBTVShowFormatTokens")
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
        save()
    }

    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
        if let token = representedObject as? Token {
            if token.isPlaceholder {
                return localizedMetadataKeyName(token.text.trimmingCharacters(in: separators))
            } else {
                return token.text
            }
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
        let control = editingString.hasPrefix("{") && editingString.hasSuffix("}")
        return Token(text: editingString, isPlaceholder: control)
    }

    func tokenField(_ tokenField: NSTokenField, editingStringForRepresentedObject representedObject: Any) -> String? {
        if let token =  representedObject as? Token {
            return token.isPlaceholder ? "/\(token.text)/" : token.text
        }
        return representedObject as? String
    }

    func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
        return tokens
    }

    private let pasteboardType = NSPasteboard.PasteboardType(rawValue: "SublerTokenDataType")

    func tokenField(_ tokenField: NSTokenField, writeRepresentedObjects objects: [Any], to pboard: NSPasteboard) -> Bool {
        if let tokens = objects as? [Token] {
            if let data = try? JSONEncoder().encode(tokens) {
                pboard.setData(data, forType: pasteboardType)
            }
            let string = tokens.reduce("", { "\($0)/\($1.text)" })
            pboard.setString(string, forType: NSPasteboard.PasteboardType.string)
            return true
        } else {
            return false
        }
    }

    func tokenField(_ tokenField: NSTokenField, readFrom pboard: NSPasteboard) -> [Any]? {
        if let data = pboard.data(forType: pasteboardType),
            let tokens = try? JSONDecoder().decode([Token].self, from: data) {
            return tokens
        } else if let string = pboard.string(forType: .string) {
            return [string]
        } else {
            return nil
        }
    }

    // MARK: Format Token Field Delegate Menu

    func tokenField(_ tokenField: NSTokenField, hasMenuForRepresentedObject representedObject: Any) -> Bool {
        if let token =  representedObject as? Token, token.isPlaceholder {
            return true
        } else {
            return false
        }
    }

    func tokenField(_ tokenField: NSTokenField, menuForRepresentedObject representedObject: Any) -> NSMenu? {
        if let token =  representedObject as? Token, token.isPlaceholder {
            return menu(for: token)
        } else {
            return nil
        }
    }

    @IBAction func setTokenCase(_ sender: NSMenuItem) {
        guard let token = sender.representedObject as? Token,
            let tokenCase = Token.Case(rawValue: sender.tag) else { return }

        if token.textCase == tokenCase {
            token.textCase = .none
        } else {
            token.textCase = tokenCase
        }

        save()
    }

    @IBAction func setTokenPadding(_ sender: NSMenuItem) {
        guard let token = sender.representedObject as? Token,
            let tokenPadding = Token.Padding(rawValue: sender.tag) else { return }

        if token.textPadding == tokenPadding {
            token.textPadding = .none
        } else {
            token.textPadding = tokenPadding
        }

        save()
    }

    private func menu(for token: Token) -> NSMenu {
        let menu = NSMenu(title: "Item Menu")
        menu.autoenablesItems = false

        menu.addItem(caseMenuItem(title: NSLocalizedString("Capitalize", comment: ""), tag: Token.Case.capitalize.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("lowercase", comment: ""), tag: Token.Case.lower.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("UPPERCASE", comment: ""), tag: Token.Case.upper.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("CamelCase", comment: ""), tag: Token.Case.camel.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("snake_case", comment: ""), tag: Token.Case.snake.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("train-case", comment: ""), tag: Token.Case.train.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("dot.case", comment: ""), tag: Token.Case.dot.rawValue, token: token))

        menu.addItem(paddingMenuItem(title: NSLocalizedString("Leading zero", comment: ""), tag: Token.Padding.leadingzero.rawValue, token: token))

        return menu
    }

    private func caseMenuItem(title: String, tag: Int, token: Token) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(setTokenCase(_:)), keyEquivalent: "")
        item.isEnabled = true
        item.representedObject = token
        item.tag = tag
        if tag == token.textCase.rawValue {
            item.state = .on
        }
        return item
    }

    private func paddingMenuItem(title: String, tag: Int, token: Token) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(setTokenPadding(_:)), keyEquivalent: "")
        item.isEnabled = true
        item.representedObject = token
        item.tag = tag
        if tag == token.textPadding.rawValue {
            item.state = .on
        }
        return item
    }
    
}
