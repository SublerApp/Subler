//
//  MetadataPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 10/08/2017.
//

import Cocoa

class MetadataPrefsViewController : NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTokenFieldDelegate, NSTextFieldDelegate {

    @IBOutlet var builtInTokenField: NSTokenField!
    @IBOutlet var addMetadataPopUpButton: NSPopUpButton!
    @IBOutlet var removeMetadataButton: NSButton!

    @IBOutlet var tableView: NSTableView!

    @IBOutlet var typesController: NSArrayController!
    @objc var types: [String]

    var movieMap: MetadataResultMap
    var tvShowMap: MetadataResultMap

    var map: MetadataResultMap

    var currentTokens: [String]
    var matches: [String]

    var selectionObserver: NSKeyValueObservation?
    let sort: (MetadataResultMapItem, MetadataResultMapItem) -> Bool

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "MetadataPrefsViewController")
    }

    init() {
        self.types = [NSLocalizedString("Movie", comment: ""), NSLocalizedString("TV Show", comment: "")]

        // Load data from preferences
        let savedMovieMap = UserDefaults.standard.map(forKey: "SBMetadataMovieResultMap2")
        let savedTvShowMap = UserDefaults.standard.map(forKey: "SBMetadataTvShowResultMap2")

        self.movieMap = savedMovieMap ?? MetadataResultMap.movieDefaultMap
        self.tvShowMap = savedTvShowMap ?? MetadataResultMap.tvShowDefaultMap

        self.map = movieMap

        self.currentTokens = []
        self.matches = []

        let context = MP42Metadata.availableMetadata
        self.sort = { (obj1: MetadataResultMapItem ,obj2: MetadataResultMapItem) -> Bool in
            if let right = context.index(of: obj1.key),
                let left = context.index(of: obj2.key) {
                return right > left ? false : true
            }
            return false
        }


        super.init(nibName: nil, bundle: nil)

        self.title = NSLocalizedString("Metadata", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        builtInTokenField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")

        if let menu = addMetadataPopUpButton.menu {
            for (index, key) in MP42Metadata.writableMetadata.enumerated() {
                let item = NSMenuItem(title: localizedMetadataKeyName(key), action: nil, keyEquivalent: "")
                item.tag = index
                item.representedObject = key
                menu.addItem(item)
            }
        }

        selectionObserver = typesController.observe(\.selectionIndex, options: [.initial, .new]) { [weak self] observed, change in
            guard let s = self else { return }
            if observed.selectionIndex > 0 {
                s.currentTokens = MetadataResult.Key.tvShowKeysStrings
                s.map = s.tvShowMap
            }
            else {
                s.currentTokens = MetadataResult.Key.movieKeysStrings
                s.map = s.movieMap
            }
            s.map.items.sort(by: s.sort)
            s.tableView.reloadData()
            s.builtInTokenField.stringValue = s.currentTokens.reduce("", { "\($0)/\($1)" })
        }
    }

    private func save() {
        UserDefaults.standard.set(movieMap, forKey: "SBMetadataMovieResultMap2")
        UserDefaults.standard.set(tvShowMap, forKey: "SBMetadataTvShowResultMap2")
    }

    @IBAction func addMetadataItem(_ sender: NSPopUpButton) {
        if let key = sender.selectedItem?.representedObject as? String {
            let item = MetadataResultMapItem(key: key)
            map.items.append(item)
            map.items.sort(by: sort)
            if let index = map.items.index(where: { $0 === item }) {
                tableView.insertRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            }
            save()
        }
    }

    @IBAction func removeMetadata(_ sender: Any) {
        for index in tableView.selectedRowIndexes.reversed() {
            map.items.remove(at: index)
        }
        tableView.removeRows(at: tableView.selectedRowIndexes, withAnimation: .slideDown)
        save()
    }

    @IBAction func restoreDefaults(_ sender: Any) {
        if typesController.selectionIndex > 0 {
            tvShowMap = MetadataResultMap.tvShowDefaultMap;
            map = tvShowMap;
        }
        else {
            movieMap = MetadataResultMap.movieDefaultMap;
            map = movieMap;
        }
        map.items.sort(by: sort)
        tableView.reloadData()
        save()
    }

    // MARK: Table View

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.tableView {
            return map.items.count
        } else {
            return 0
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == self.tableView {

            let item = map.items[row]

            if tableColumn?.identifier == NSUserInterfaceItemIdentifier("annotation"),
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("annotation"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = item.localizedKeyDisplayName
                return cell
            }
            else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("value"),
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("value"), owner: self) as? TokenCellView {
                cell.tokenView.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
                cell.tokenView.objectValue = item.value
                return cell
            }
        }

        return nil
    }

    // MARK: Format Token Field Delegate

    override func controlTextDidEndEditing(_ obj: Notification) {
        if let tokenField = obj.object as? NSTokenField {
            let row = tableView.row(for: tokenField)

            if row != -1, let tokens = tokenField.objectValue as? [Token] {
                map.items[row].value = tokens
            }
        }

        save()
    }

    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
        if let token = representedObject as? Token {
            if token.isPlaceholder {
                return MetadataResult.Key.localizedDisplayName(key: token.text)
            } else {
                return token.text
            }
        }
        return representedObject as? String
    }

    func tokenField(_ tokenField: NSTokenField, styleForRepresentedObject representedObject: Any) -> NSTokenField.TokenStyle {
        if let token = representedObject as? Token {
            return token.isPlaceholder ? .rounded : .none
        } else {
            return .none
        }
    }

    func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
        let control = editingString.hasPrefix("{") && editingString.hasSuffix("}")
        return Token(text: editingString, isPlaceholder: control)
    }

    func tokenField(_ tokenField: NSTokenField, completionsForSubstring substring: String, indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [Any]? {
        matches = currentTokens.filter { $0.hasPrefix(substring) }
        return matches
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
            let string = tokens.reduce("", { "\($0)/{\($1.text)}" })
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
        if tokenField == builtInTokenField {
            return false
        } else if let token =  representedObject as? Token, token.isPlaceholder {
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
