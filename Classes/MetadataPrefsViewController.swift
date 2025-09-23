//
//  MetadataPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 10/08/2017.
//

import Cocoa
import MP42Foundation

class MetadataPrefsViewController : NSViewController, NSTableViewDelegate, NSTableViewDataSource, TokenChangeObserver {

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

    var selectionObserver: NSKeyValueObservation?
    let sort: (MetadataResultMapItem, MetadataResultMapItem) -> Bool

    let tokenDelegate: TokenDelegate
    let tableTokenDelegate: TokenDelegate

    override var nibName: NSNib.Name? {
        return "MetadataPrefsViewController"
    }

    init() {
        self.types = [NSLocalizedString("Movie", comment: ""), NSLocalizedString("TV Show", comment: "")]

        // Load data from preferences
        self.movieMap = MetadataPrefs.movieResultMap
        self.tvShowMap = MetadataPrefs.tvShowResultMap
        self.map = movieMap
        self.currentTokens = []

        let context = MP42Metadata.availableMetadata
        self.sort = { (obj1: MetadataResultMapItem ,obj2: MetadataResultMapItem) -> Bool in
            if let right = context.firstIndex(of: obj1.key),
                let left = context.firstIndex(of: obj2.key) {
                return right > left ? false : true
            }
            return false
        }

        self.tokenDelegate = TokenDelegate(displayMenu: false, displayString: { MetadataResult.Key.localizedDisplayName(key: $0.text) })
        self.tableTokenDelegate = TokenDelegate(displayMenu: true, displayString: { MetadataResult.Key.localizedDisplayName(key: $0.text) })

        super.init(nibName: nil, bundle: nil)

        self.title = NSLocalizedString("Metadata", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tokenDelegate.delegate = self
        tableTokenDelegate.delegate = self

        builtInTokenField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
        builtInTokenField.delegate = tokenDelegate

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

            s.updateControlsState()
        }

        updateControlsState()
    }

    private func updateControlsState() {
        removeMetadataButton.isEnabled = tableView.selectedRow != -1
    }

    private func save() {
        MetadataPrefs.movieResultMap = movieMap
        MetadataPrefs.tvShowResultMap = tvShowMap
    }

    @IBAction func addMetadataItem(_ sender: NSPopUpButton) {
        if let key = sender.selectedItem?.representedObject as? String {
            let item = MetadataResultMapItem(key: key)
            map.items.append(item)
            map.items.sort(by: sort)
            if let index = map.items.firstIndex(where: { $0 === item }) {
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

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateControlsState()
    }

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
                cell.tokenView.delegate = tableTokenDelegate
                cell.tokenView.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
                cell.tokenView.objectValue = item.value
                return cell
            }
        }

        return nil
    }

    // MARK: Format Token Field Delegate

    func tokenDidChange(_ obj: Notification?) {
        if let tokenField = obj?.object as? NSTokenField {
            let row = tableView.row(for: tokenField)

            if row != -1, let tokens = tokenField.objectValue as? [Token] {
                map.items[row].value = tokens
            }
        }

        save()
    }

}
