//
//  MetadataPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 10/08/2017.
//

import Cocoa

@objc(SBMetadataPrefsViewController) class MetadataPrefsViewController : NSViewController, NSTableViewDelegate, NSTokenFieldDelegate, NSTextFieldDelegate {

    @IBOutlet var builtInTokenField: NSTokenField!
    @IBOutlet var addMetadataPopUpButton: NSPopUpButton!
    @IBOutlet var removeMetadataButton: NSButton!

    @IBOutlet var tableView: NSTableView!

    @IBOutlet var typesController: NSArrayController!
    @IBOutlet var typesTableView: NSTableView!
    @objc var types: [String]

    var movieMap: MetadataResultMap
    var tvShowMap: MetadataResultMap

    @objc dynamic var map: MetadataResultMap
    @IBOutlet var itemsController: NSArrayController!

    var currentTokens: [String]
    var matches: [String]

    var selectionObserver: NSKeyValueObservation?

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "SBMetadataPrefsViewController")
    }

    init() {
        self.types = [NSLocalizedString("Movie", comment: ""), NSLocalizedString("TV Show", comment: "")]

        // Load data from preferences
        let savedMovieMap = UserDefaults.standard.map(forKey: "SBMetadataMovieResultMap")
        let savedTvShowMap = UserDefaults.standard.map(forKey: "SBMetadataTvShowResultMap")

        self.movieMap = savedMovieMap ?? MetadataResultMap.movieDefaultMap
        self.tvShowMap = savedTvShowMap ?? MetadataResultMap.tvShowDefaultMap

        self.map = movieMap

        self.currentTokens = []
        self.matches = []

        super.init(nibName: self.nibName, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func loadView() {
        super.loadView()

        builtInTokenField.tokenizingCharacterSet = CharacterSet(charactersIn: "%")

        if let menu = addMetadataPopUpButton.menu {
            for (index, key) in MP42Metadata.writableMetadata.enumerated() {
                let item = NSMenuItem(title: localizedMetadataKeyName(key), action: nil, keyEquivalent: "")
                item.tag = index
                menu.addItem(item)
            }
        }

        let context = MP42Metadata.availableMetadata
        let sortDescriptor = NSSortDescriptor(keyPath: \MetadataResultMapItem.key, ascending: true) { obj1, obj2 -> ComparisonResult in
            if let right = context.index(of: obj1 as! String),
                let left = context.index(of: obj2 as! String) {
                return right > left ? .orderedDescending : .orderedAscending
            }
            return .orderedSame
        }

        itemsController.sortDescriptors = [sortDescriptor]
        itemsController.setSelectionIndexes(IndexSet())

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
            s.itemsController.setSelectionIndexes(IndexSet())
            s.builtInTokenField.stringValue = s.currentTokens.reduce("", { "\($0)%\($1)" })
        }
    }

    private func save() {
        UserDefaults.standard.set(movieMap, forKey: "SBMetadataMovieResultMap")
        UserDefaults.standard.set(tvShowMap, forKey: "SBMetadataTvShowResultMap")
    }

    @IBAction func addMetadataItem(_ sender: NSPopUpButton) {
        if let key = sender.selectedItem?.title {
            let item = MetadataResultMapItem(key: key, value: [""])
            itemsController.addObject(item)
            itemsController.rearrangeObjects()
            save()
        }
    }

    @IBAction func removeMetadata(_ sender: Any) {
        for object in itemsController.selectedObjects {
            itemsController.removeObject(object)
        }
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
        save()
    }

    // MARK: Table View

    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        if tableView == self.tableView,
            let view = rowView.view(atColumn: 1) as? NSView, let tokenField = view.subviews.first as? NSTokenField {
            tokenField.tokenizingCharacterSet = CharacterSet(charactersIn: "%")
        }
    }

    // MARK: Format Token Field Delegate

    override func controlTextDidEndEditing(_ obj: Notification) {
        save()
    }

    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
        if let stringValue = representedObject as? String, stringValue.hasPrefix("{") {
            return MetadataResult.Key.localizedDisplayName(key: stringValue)
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

    func tokenField(_ tokenField: NSTokenField, completionsForSubstring substring: String, indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [Any]? {
        matches = currentTokens.filter { $0.hasPrefix(substring) }
        return matches

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
