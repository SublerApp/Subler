//
//  MovieViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 11/03/2019.
//

import Cocoa
import Quartz
import MP42Foundation

class MovieViewController: NSViewController, NSTableViewDataSource, ExpandedTableViewDelegate, ImageBrowserViewDelegate, NSDraggingDestination {

    var metadata: MP42Metadata {
        didSet {
            reloadData()
        }
    }

    // Metadata tab
    private var tags: [MP42MetadataItem]

    private let ratings: [String]

    private lazy var dummyCell: NSTableCellView = {
        return self.metadataTableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TextCellForSizing"), owner: self) as! NSTableCellView
    }()
    private lazy var dummyCellWidth: NSLayoutConstraint = {
        let constraint = NSLayoutConstraint.init(item: self.dummyCell, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 500)
        self.dummyCell.addConstraint(constraint)
        return constraint
    }()
    private lazy var column: NSTableColumn = {
        return self.metadataTableView.tableColumns[1]
    }()
    private var columnWidth: CGFloat
    private var previousColumnWidth: CGFloat
    private var rowHeights: Dictionary<String, CGFloat>

    @IBOutlet var tagsPopUp: NSPopUpButton!
    @IBOutlet var setsPopUp: NSPopUpButton!

    @IBOutlet var removeTagButton: NSButton!
    @IBOutlet var metadataTableView: ExpandedTableView!

    private let metadataPBoardType = NSPasteboard.PasteboardType(rawValue: "SublerMetadataPBoardTypeV2")

    // Set save window
    @IBOutlet var saveSetWindow: NSWindow!
    @IBOutlet var saveSetName: NSTextField!
    @IBOutlet var keepArtworks: NSButton!
    @IBOutlet var keepAnnotations: NSButton!

    // Artwork tab
    private var artworks: [MP42MetadataItem]

    @IBOutlet var removeArtworkButton: NSButton!
    @IBOutlet var artworksView: ImageBrowserView!

    private let artworksPBoardType = NSPasteboard.PasteboardType(rawValue: "SublerCoverArtPBoardType")

    override var nibName: NSNib.Name? {
        return "MovieView"
    }

    init(metadata: MP42Metadata) {
        self.metadata = metadata
        self.tags = []
        self.artworks = []
        self.ratings = MP42Ratings.defaultManager.ratings
        self.columnWidth = 0
        self.previousColumnWidth = 0
        self.rowHeights = Dictionary()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        artworksView.delegate = nil
        artworksView.dataSource = nil
        artworksView.setDraggingDestinationDelegate(nil)
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateSetsMenu(self)

        NotificationCenter.default.addObserver(self, selector: #selector(updateSetsMenu(_:)), name: PresetManager.updateNotification, object: nil)

        if let menu = tagsPopUp.menu {
            let identifiersMenu = MP42Metadata.writableMetadata
            for (index, identifier) in identifiersMenu.enumerated() {
                let item = NSMenuItem(title: localizedMetadataKeyName(identifier), action: nil, keyEquivalent: "")
                item.tag = index
                menu.addItem(item)
            }
        }

        columnWidth = column.width

        metadataTableView.doubleAction = #selector(doubleClickAction(_:))
        metadataTableView.target = self
        metadataTableView.pasteboardTypes = [metadataPBoardType]
        metadataTableView.scrollRowToVisible(0)

        artworksView.pasteboardTypes = [artworksPBoardType, NSPasteboard.PasteboardType.tiff, NSPasteboard.PasteboardType.png]
        artworksView.setZoomValue(1.0)

        reloadData()
    }

    private func reloadData() {
        rowHeights.removeAll(keepingCapacity: true)
        updateMetadataArray()
        metadataTableView.reloadData()
        updateArtworksArray()
        artworksView.reloadData()
        view.undoManager?.removeAllActions(withTarget: self)
    }

    // MARK: Metadata

    private func updateMetadataArray() {

        let dataTypes: UInt = MP42MetadataItemDataType.string.rawValue | MP42MetadataItemDataType.stringArray.rawValue | MP42MetadataItemDataType.bool.rawValue | MP42MetadataItemDataType.integer.rawValue | MP42MetadataItemDataType.integerArray.rawValue | MP42MetadataItemDataType.date.rawValue

        tags = metadata.metadataItemsFiltered(by: MP42MetadataItemDataType(rawValue: dataTypes))

        let context = MP42Metadata.availableMetadata

        tags.sort { (obj1, obj2) -> Bool in
            if let right = context.firstIndex(of: obj1.identifier),
                let left = context.firstIndex(of: obj2.identifier) {
                return right < left ? true : false
            } else {
                return false
            }
        }
    }

    private func add(metadataItems items: [MP42MetadataItem]) {
        for item in items {
            metadata.addItem(item)
            rowHeights[item.identifier] = nil
        }

        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { (target) in
                target.remove(metadataItems: items)
            }

            if undo.isUndoing == false {
                undo.setActionName(NSLocalizedString("Insert", comment: "Undo tag insert."))
            }
        }

        updateMetadataArray()
        metadataTableView.reloadData()
    }

    private func remove(metadataItems items: [MP42MetadataItem]) {
        for item in items {
            metadata.removeItem(item)
        }

        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { (target) in
                target.add(metadataItems: items)
            }

            if undo.isUndoing == false {
                undo.setActionName(NSLocalizedString("Delete", comment: "Undo tag delete."))
            }
        }

        updateMetadataArray()
        metadataTableView.reloadData()
    }

    private func replace(metadataItem item: MP42MetadataItem, withItem newItem: MP42MetadataItem) {
        metadata.removeItem(item)
        metadata.addItem(newItem)

        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { (target) in
                target.replace(metadataItem: newItem, withItem: item)
            }

            if undo.isUndoing == false {
                undo.setActionName(NSLocalizedString("Editing", comment: "Undo tag editing."))
                view.window?.windowController?.document?.updateChangeCount(.changeDone)
            } else {
                view.window?.windowController?.document?.updateChangeCount(.changeUndone)
            }
        }

        updateMetadataArray()

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0

        if let index = tags.firstIndex(of: newItem) {
            let indexSet = IndexSet(integer: index)
            let colIndexSet = IndexSet(integer: 1)

            rowHeights[newItem.identifier] = nil
            metadataTableView.reloadData(forRowIndexes: indexSet, columnIndexes: colIndexSet)
            metadataTableView.noteHeightOfRows(withIndexesChanged: indexSet)
        }

        NSAnimationContext.endGrouping()
    }

    @IBAction func addTag(_ sender: Any?) {
        // End editing
        view.window?.makeFirstResponder(metadataTableView)

        guard let sender = sender as? NSPopUpButton else { return }

        let identifier = MP42Metadata.writableMetadata[sender.selectedTag()]

        if metadata.metadataItemsFiltered(byIdentifier: identifier).isEmpty {
            let item = MP42MetadataItem(identifier: identifier, value: "" as NSCopying & NSObjectProtocol, dataType: MP42MetadataItemDataType.unspecified, extendedLanguageTag: nil)
            add(metadataItems: [item])
        }

        if let item = metadata.metadataItemsFiltered(byIdentifier: identifier).first,
            let index = tags.firstIndex(of: item) {
            metadataTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            metadataTableView.scrollRowToVisible(index)
        }
    }

    @IBAction func removeTag(_ sender: Any?) {
        // End editing
        view.window?.makeFirstResponder(metadataTableView)

        let items = metadataTableView.selectedRowIndexes.compactMap { tags[$0] }
        remove(metadataItems: items)
    }

    // MARK: Built-In presets

    private var allSet: [String] {
        get {
            return MP42Metadata.writableMetadata
        }
    }

    private var tvShowSet: [String] {
        get {
            return [MP42MetadataKeyName, MP42MetadataKeyArtist, MP42MetadataKeyAlbum, MP42MetadataKeyReleaseDate, MP42MetadataKeyTrackNumber, MP42MetadataKeyDiscNumber, MP42MetadataKeyTVShow, MP42MetadataKeyTVEpisodeNumber, MP42MetadataKeyTVNetwork, MP42MetadataKeyTVEpisodeID, MP42MetadataKeyTVSeason, MP42MetadataKeyUserGenre, MP42MetadataKeyDescription, MP42MetadataKeyLongDescription]
        }
    }

    private var movieSet: [String] {
        get {
            return [MP42MetadataKeyName, MP42MetadataKeyArtist, MP42MetadataKeyAlbum, MP42MetadataKeyUserGenre, MP42MetadataKeyReleaseDate, MP42MetadataKeyTrackNumber, MP42MetadataKeyDiscNumber, MP42MetadataKeyCast, MP42MetadataKeyDirector, MP42MetadataKeyScreenwriters, MP42MetadataKeyUserGenre, MP42MetadataKeyDescription, MP42MetadataKeyLongDescription, MP42MetadataKeyRating, MP42MetadataKeyCopyright]
        }
    }

    // MARK: Sets management

    @IBAction func addMetadataSet(_ sender: NSMenuItem) {
        var itemsToBeAdded: [MP42MetadataItem] = []
        var identifiers: Set<String> = Set()

        switch sender.tag {
        case 0:
            identifiers = Set(allSet)
        case 1:
            identifiers = Set(movieSet)
            let mediaKind = MP42MetadataItem(identifier: MP42MetadataKeyMediaKind, value: 9 as NSCopying & NSObjectProtocol, dataType: .integer, extendedLanguageTag: nil)
            itemsToBeAdded.append(mediaKind)
        case 2:
            identifiers = Set(tvShowSet)
            let mediaKind = MP42MetadataItem(identifier: MP42MetadataKeyMediaKind, value: 10 as NSCopying & NSObjectProtocol, dataType: .integer, extendedLanguageTag: nil)
            itemsToBeAdded.append(mediaKind)
        default:
            break
        }

        let existingIdentifiers = Set(tags.map { $0.identifier} )
        identifiers.subtract(existingIdentifiers)

        itemsToBeAdded.append(contentsOf: identifiers.map { MP42MetadataItem(identifier: $0, value: "" as NSCopying & NSObjectProtocol, dataType: .unspecified, extendedLanguageTag: nil)} )

        add(metadataItems: itemsToBeAdded)
    }

    @IBAction func updateSetsMenu(_ sender: Any) {
        guard let menu = setsPopUp?.menu else { return }

        while menu.numberOfItems > 1 {
            menu.removeItem(at: 1)
        }

        let saveSetItem = NSMenuItem(title: NSLocalizedString("Save Set…", comment: "Set menu"), action: #selector(showSaveSet(_:)), keyEquivalent: "")
        saveSetItem.target = self
        menu.addItem(saveSetItem)

        let allSetItem = NSMenuItem(title: NSLocalizedString("All", comment: "Set menu All set"), action: #selector(addMetadataSet(_:)), keyEquivalent: "")
        allSetItem.target = self
        allSetItem.tag = 0
        menu.addItem(allSetItem)

        let movieSetItem = NSMenuItem(title: NSLocalizedString("Movie", comment: "Set menu Movie set"), action: #selector(addMetadataSet(_:)), keyEquivalent: "")
        movieSetItem.target = self
        movieSetItem.tag = 1
        menu.addItem(movieSetItem)

        let tvSetItem = NSMenuItem(title: NSLocalizedString("TV Show", comment: "Set menu TV Show Set"), action: #selector(addMetadataSet(_:)), keyEquivalent: "")
        tvSetItem.target = self
        tvSetItem.tag = 2
        menu.addItem(tvSetItem)

        let presets = PresetManager.shared.metadataPresets

        if presets.isEmpty == false {
            menu.addItem(NSMenuItem.separator())
        }

        for (index, preset) in presets.enumerated() {
            let item = NSMenuItem(title: preset.title, action: #selector(applySet(_:)), keyEquivalent: "")
            if index < 9 {
                item.keyEquivalent = "\(index + 1)"
            }
            item.target = self
            item.tag = index

            menu.addItem(item)
        }
    }

    @IBAction func applySet(_ sender: NSMenuItem) {
        let index = sender.tag
        let preset = PresetManager.shared.metadataPresets[index]

        let dataTypes: UInt = MP42MetadataItemDataType.string.rawValue | MP42MetadataItemDataType.stringArray.rawValue |
            MP42MetadataItemDataType.bool.rawValue | MP42MetadataItemDataType.integer.rawValue |
            MP42MetadataItemDataType.integerArray.rawValue | MP42MetadataItemDataType.date.rawValue

        let items = preset.metadata.metadataItemsFiltered(by: MP42MetadataItemDataType(rawValue: dataTypes))

        if preset.replaceAnnotations {
            remove(metadataItems: metadata.metadataItemsFiltered(by: MP42MetadataItemDataType(rawValue: dataTypes)))
        }

        if items.isEmpty == false {
            let identifiers = items.map { $0.identifier }
            remove(metadataItems: metadata.metadataItemsFiltered(byIdentifiers: identifiers))
            add(metadataItems: items)
        }

        let artworkItems = preset.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyCoverArt)

        if preset.replaceArtworks {
            remove(metadataItems: metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyCoverArt))
        }

        if artworkItems.isEmpty == false {
            add(metadataArtworks: artworkItems)
        }
    }

    @IBAction func showSaveSet(_ sender: Any) {
        view.window?.beginCriticalSheet(saveSetWindow, completionHandler: nil)
    }

    @IBAction func closeSaveSheet(_ sender: Any) {
        view.window?.endSheet(saveSetWindow)
    }

    @IBAction func saveSet(_ sender: Any) {
        guard let title = saveSetName?.stringValue else { return }

        let preset = MetadataPreset(title: title, metadata: metadata,
                                    replaceArtworks: keepArtworks?.state == .off,
                                    replaceAnnotations: keepAnnotations?.state == .off)

        do {
            try PresetManager.shared.append(newElement: preset)
            view.window?.endSheet(saveSetWindow)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: Table View data source

    private static let keyCell = NSUserInterfaceItemIdentifier(rawValue: "NameTextCell")
    private static let boolCell = NSUserInterfaceItemIdentifier(rawValue: "BoolCell")
    private static let textCell = NSUserInterfaceItemIdentifier(rawValue: "TextCell")
    private static let popUpCell = NSUserInterfaceItemIdentifier(rawValue: "PopUpCell")
    private static let comboCell = NSUserInterfaceItemIdentifier(rawValue: "ComboCell")

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tags.count
    }

    private func boolCell(state: Bool, tableView: NSTableView) -> CheckBoxCellView {
        guard let cell = tableView.makeView(withIdentifier: MovieViewController.boolCell, owner: self) as? CheckBoxCellView else { fatalError() }
        cell.checkboxButton.state = state ? .on : .off
        return cell
    }

    private func textCell(string: String?, tableView: NSTableView) -> NSTableCellView {
        guard let cell = tableView.makeView(withIdentifier: MovieViewController.textCell, owner: self) as? NSTableCellView else { fatalError() }
            cell.textField?.stringValue = string ?? ""
        return cell
    }

    private func popUpRatingCell(contents: [String], value: String?, tableView: NSTableView) -> PopUpCellView {
        guard let cell = tableView.makeView(withIdentifier: MovieViewController.popUpCell, owner: self) as? PopUpCellView, let popUpButton = cell.popUpButton else { fatalError() }

        popUpButton.removeAllItems()

        contents.forEach { popUpButton.menu?.addItem(withTitle: $0, action: nil, keyEquivalent: "") }

        // WTF
        let index = MP42Ratings.defaultManager.ratingIndexForiTunesCode(value ?? "")
        if index != -1 {
            popUpButton.selectItem(at: Int(index))
        } else {
            let title = value?.isEmpty ?? true ? NSLocalizedString("Unknown", comment: "") : value ?? NSLocalizedString("Unknown", comment: "")
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.tag = -1
            popUpButton.menu?.addItem(item)
            popUpButton.select(item)
        }
        return cell
    }

    private func popUpCell(contents: [(title: String, value: Int)], value: Int?, tableView: NSTableView) -> PopUpCellView {
        guard let cell = tableView.makeView(withIdentifier: MovieViewController.popUpCell, owner: self) as? PopUpCellView, let popUpButton = cell.popUpButton else { fatalError() }

        popUpButton.removeAllItems()

        contents.forEach {
            let item = NSMenuItem(title: $0.title, action: nil, keyEquivalent: "")
            item.tag = $0.value
            popUpButton.menu?.addItem(item)
        }

        if let value = value {
            popUpButton.selectItem(withTag: value)
        }

        if popUpButton.indexOfSelectedItem == -1 {
            let title = (value != nil) ? "\(String(describing: value))" : NSLocalizedString("Unknown", comment: "")
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.tag = -1
            popUpButton.menu?.addItem(item)
            popUpButton.select(item)
        }

        return cell
    }

    private func comboBoxCell(contents: [String], value: String?, tableView: NSTableView) -> ComboBoxCellView {
        guard let cell = tableView.makeView(withIdentifier: MovieViewController.comboCell, owner: self) as? ComboBoxCellView, let comboBox = cell.comboBox else { fatalError() }

        comboBox.stringValue = value ?? NSLocalizedString("Unknown", comment: "")
        comboBox.addItems(withObjectValues: contents)

        return cell
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let contentRatings: [(title: String, value: Int)] =
                   [(title: NSLocalizedString("None", comment: ""), value: 0),
                    (title: NSLocalizedString("Clean", comment: ""), value: 2),
                    (title: NSLocalizedString("Explicit", comment: ""), value: 4)]

    private static let mediaKinds: [(title: String, value: Int)] =
                   [(title: NSLocalizedString("Home Video", comment: ""), value: 0),
                    (title: NSLocalizedString("Music", comment: ""), value: 1),
                    (title: NSLocalizedString("Audiobook", comment: ""), value: 2),
                    (title: NSLocalizedString("Music Video", comment: ""), value: 6),
                    (title: NSLocalizedString("Movie", comment: ""), value: 9),
                    (title: NSLocalizedString("TV Show", comment: ""), value: 10),
                    (title: NSLocalizedString("Booklet", comment: ""), value: 11),
                    (title: NSLocalizedString("Ringtone", comment: ""), value: 14),
                    (title: NSLocalizedString("Podcast", comment: ""), value: 21),
                    (title: NSLocalizedString("iTunes U", comment: ""), value: 23),
                    (title: NSLocalizedString("Alert Tone", comment: ""), value: 27)]

    private static let hdVideo: [(title: String, value: Int)] =
                   [(title: NSLocalizedString("No", comment: ""), value: 0),
                    (title: NSLocalizedString("720p", comment: ""), value: 1),
                    (title: NSLocalizedString("1080p", comment: ""), value: 2)]

    private static let availableGenres: [String] =
                    ["Animation", "Classic TV", "Comedy", "Drama",
                     "Fitness & Workout", "Kids", "Non-Fiction",
                     "Reality TV", "Sci-Fi & Fantasy", "Sports"]

    private let keyColumn = NSUserInterfaceItemIdentifier(rawValue: "key")
    private let valueColumn = NSUserInterfaceItemIdentifier(rawValue: "value")

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let item = tags[row]

        if tableColumn?.identifier == keyColumn {

            let cell = tableView.makeView(withIdentifier: MovieViewController.keyCell, owner: self) as? NSTableCellView
            cell?.textField?.stringValue = localizedMetadataKeyName(item.identifier)
            return cell

        } else if tableColumn?.identifier == valueColumn {

            switch item.dataType {

            case .string:
                if item.identifier == MP42MetadataKeyUserGenre {
                    return comboBoxCell(contents: MovieViewController.availableGenres, value: item.stringValue, tableView: tableView)
                } else if item.identifier == MP42MetadataKeyRating {
                    return popUpRatingCell(contents: ratings, value: item.stringValue, tableView: tableView)
                } else {
                    return textCell(string: item.stringValue, tableView: tableView)
                }

            case .stringArray, .integer:
                if item.identifier == MP42MetadataKeyContentRating {
                    return popUpCell(contents: MovieViewController.contentRatings, value: item.numberValue?.intValue, tableView: tableView)
                } else if item.identifier == MP42MetadataKeyMediaKind {
                    return popUpCell(contents: MovieViewController.mediaKinds, value: item.numberValue?.intValue, tableView: tableView)
                } else if item.identifier == MP42MetadataKeyHDVideo {
                    return popUpCell(contents: MovieViewController.hdVideo, value: item.numberValue?.intValue, tableView: tableView)
                } else {
                    return textCell(string: item.stringValue, tableView: tableView)
                }

            case .integerArray:
                return textCell(string: item.stringValue, tableView: tableView)

            case .date:

                if let date = item.dateValue {
                    let formattedDate = MovieViewController.formatter.string(from: date)
                    return textCell(string: formattedDate, tableView: tableView)
                } else {
                    return textCell(string: item.stringValue, tableView: tableView)
                }

            case .bool:

                return boolCell(state: item.numberValue?.boolValue ?? false, tableView: tableView)

            default:
                return nil
            }
        }

        return nil
    }

    // MARK: Table View editing

    private func stringsArray(fromString string: NSString) -> [String] {
        let splitElements = ",\\s*+"
        return string.mp42_components(separatedByRegex: splitElements)
    }

    private func numbersArray(fromString string: String) -> [Int] {
        let index = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        let separator = UnsafeMutablePointer<Int>.allocate(capacity: 3)
        let count = UnsafeMutablePointer<Int>.allocate(capacity: 1)

        _ = withVaList([index, separator, count], { pointer in
            vsscanf(string, "%u%[/- ]%u", pointer)
        })

        return [index.pointee, count.pointee]
    }

    @IBAction func setMetadataStringValue(_ sender: NSTextField) {
        let row = metadataTableView.row(for: sender)

        if row == -1 { return }

        let item = tags[row]

        if sender.stringValue == item.stringValue { return }

        if item.dataType == .date, let date = item.dateValue,  MovieViewController.formatter.string(from: date) == item.stringValue {
            return
        }

        var value: Any = ""
        var type = item.dataType

        switch item.dataType {
        case .string:
            if item.identifier == MP42MetadataKeyReleaseDate {
                if let date = MovieViewController.formatter.date(from: sender.stringValue) {
                    value = date
                    type = .date
                } else {
                    value = sender.stringValue
                }
            } else {
                value = sender.stringValue
            }

        case .stringArray:
            value = stringsArray(fromString: sender.stringValue as NSString)
            break

        case .integer:
            value = sender.integerValue

        case .integerArray:
            value = numbersArray(fromString: sender.stringValue)

        case .date:
            if let date = MovieViewController.formatter.date(from: sender.stringValue) {
                value = date
            } else {
                value = sender.stringValue
                type = .string
            }

        case .bool:
            value = sender.integerValue

        default:
            break
        }

        let editedItem = MP42MetadataItem(identifier: item.identifier, value: value as! NSCopying & NSObjectProtocol, dataType: type, extendedLanguageTag: item.extendedLanguageTag)

        replace(metadataItem: item, withItem: editedItem)
    }

    @IBAction func setMetadataBoolValue(_ sender: NSButton) {
        let row = metadataTableView.row(for: sender)

        if row == -1 { return }

        let item = tags[row]

        let editedItem = MP42MetadataItem(identifier: item.identifier, value: sender.state == .on ? true as NSCopying & NSObjectProtocol : false as NSCopying & NSObjectProtocol, dataType: item.dataType, extendedLanguageTag: item.extendedLanguageTag)

        replace(metadataItem: item, withItem: editedItem)
    }

    @IBAction func setMetadataIntValue(_ sender: NSPopUpButton) {
        if sender.selectedTag() == -1 { return }

        let row = metadataTableView.row(for: sender)

        if row == -1 { return }

        let item = tags[row]

        let index = sender.indexOfSelectedItem

        var value: Any = -1

        switch item.dataType {
        case .string:
            if item.identifier == MP42MetadataKeyRating {
                let ratings = MP42Ratings.defaultManager.iTunesCodes
                if index < ratings.count {
                    value = ratings[index]
                } else {
                    value = item.value as Any
                }
            }

        case .integer:
            if item.identifier == MP42MetadataKeyContentRating {
                value = MovieViewController.contentRatings[index].value
            } else if item.identifier == MP42MetadataKeyMediaKind {
                value = MovieViewController.mediaKinds[index].value
            } else if item.identifier == MP42MetadataKeyHDVideo {
                value = MovieViewController.hdVideo[index].value
            }

        default:
            break
        }

        let editedItem = MP42MetadataItem(identifier: item.identifier, value: value as! NSCopying & NSObjectProtocol, dataType: item.dataType, extendedLanguageTag: item.extendedLanguageTag)

        replace(metadataItem: item, withItem: editedItem)
    }

    // MARK: Table View delegate

    @IBAction func doubleClickAction(_ sender: Any?) {
        // make sure they clicked a real cell and not a header or empty row
        guard let sender = sender as? NSTableView else { return }

        if sender.clickedRow != -1 && sender.clickedColumn == 1 {
            sender.editColumn(sender.clickedColumn, row: sender.clickedRow, with: nil, select: true)
        }
    }

    func deleteSelection(in tableview: NSTableView) {
        removeTag(tableview)
    }

    func copySelection(in tableview: NSTableView) {
        let selectedRows = tableview.selectedRowIndexes
        let items = tags.enumerated().filter { selectedRows.contains($0.offset) == true } .map { $0.element }

        let itemsDescriptions = items.map { "\($0.identifier): \($0.stringValue ?? "")\n"}
        let description = itemsDescriptions.reduce("") {$0 + $1 }

        let pb = NSPasteboard.general
        pb.declareTypes([.string, metadataPBoardType], owner: nil)
        pb.setString(description, forType: .string)
        pb.setData(NSKeyedArchiver.archivedData(withRootObject: items), forType: metadataPBoardType)
    }

    func cutSelection(in tableview: NSTableView) {
        copySelection(in: tableview)
        removeTag(tableview)
    }

    func paste(to tableview: NSTableView) {
        let pb = NSPasteboard.general
        if let archivedData = pb.data(forType: metadataPBoardType),
            let data = NSKeyedUnarchiver.unarchiveObject(with: archivedData) as? [MP42MetadataItem] {
            add(metadataItems: data)
        }
    }

    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        return ""
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let item = tags[row]

        var calculateHeight = false
        let minHeight = CGFloat(14)
        var height = CGFloat(0)

        // Height calculation is slow, so calculate only if stricly necessary.
        switch item.dataType {
        case .string, .stringArray, .date:
            calculateHeight = true
        default:
            calculateHeight = false
        }

        if let cachedHeight = rowHeights[item.identifier] {
            height = cachedHeight
        } else if calculateHeight {
            // Set the width in the dummy cell, and let autolayout calculate the height.
            dummyCellWidth.constant = columnWidth
            dummyCell.textField?.preferredMaxLayoutWidth = columnWidth
            if let string = item.stringValue {
                dummyCell.textField?.stringValue = string
            }
            height = dummyCell.fittingSize.height
            rowHeights[item.identifier] = height
        }

        return (height < minHeight) ? minHeight : height;
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        previousColumnWidth = columnWidth
        columnWidth = column.width

        if columnWidth > previousColumnWidth {
            rowHeights = rowHeights.filter { $0.value < 14.0 }
        } else {
            rowHeights.removeAll(keepingCapacity: true)
        }

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        metadataTableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<metadataTableView.numberOfRows))
        NSAnimationContext.endGrouping()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let enabled = metadataTableView.selectedRow != -1 ? true : false
        removeTagButton.isEnabled = enabled
    }

    // MARK: Artworks

    private func updateArtworksArray() {
        artworks = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyCoverArt)
    }

    private func add(metadataArtworks items: [MP42MetadataItem]) {
        metadata.addItems(items)

        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { (target) in
                target.remove(metadataArtworks: items)
            }

            if undo.isUndoing == false {
                undo.setActionName(NSLocalizedString("Insert", comment: "Undo cover art insert."))
            }
        }

        updateArtworksArray()
        artworksView.reloadData()
    }

    private func remove(metadataArtworks items: [MP42MetadataItem]) {
        metadata.removeItems(items)

        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { (target) in
                target.add(metadataArtworks: items)
            }

            if undo.isUndoing == false {
                undo.setActionName(NSLocalizedString("Delete", comment: "Undo cover art delete"))
            }
        }

        updateArtworksArray()
        artworksView.reloadData()
    }

    private func replace(metadataArtworks items: [MP42MetadataItem], withItems newItems: [MP42MetadataItem]) {

        metadata.removeItems(items)
        metadata.addItems(newItems)

        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { (target) in
                target.replace(metadataArtworks: newItems, withItems: items)
            }

            if undo.isUndoing == false {
                undo.setActionName(NSLocalizedString("Move", comment: "Undo cover art delete"))
            }
        }

        updateArtworksArray()
        artworksView.reloadData()
    }

    @IBAction func removeArtwork(_ sender: Any?) {
        imageBrowser(artworksView, removeItemsAt: artworksView.selectionIndexes())
        artworksView.reloadData()
    }

    private func add(artworks: [Any]) -> Bool {
        let items = artworks.compactMap { (artwork: Any) -> MP42Image? in
            if let url = artwork as? URL {
                let value = try? url.resourceValues(forKeys: [URLResourceKey.typeIdentifierKey])

                if let type = value?.typeIdentifier, UTTypeConformsTo(type as CFString, "public.jpeg" as CFString), let data = try? Data(contentsOf: url) {
                    return MP42Image(data: data, type: MP42_ART_JPEG)
                } else if let image = NSImage(contentsOf: url) {
                    return MP42Image(image: image)
                }
            } else if let image = artwork as? NSImage {
                return MP42Image(image: image)
            } else if let image = artwork as? MP42Image {
                return image
            }
            return nil
            }.map {
                return MP42MetadataItem(identifier: MP42MetadataKeyCoverArt, value: $0, dataType: .image, extendedLanguageTag: nil)
        }

        if items.isEmpty {
            return false
        } else {
            add(metadataArtworks: items)
            return true
        }
    }

    @IBAction func selectArtwork(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["public.image"]

        guard let window = view.window else { return }

        panel.beginSheetModal(for: window) { (result) in
            if result == NSApplication.ModalResponse.OK {
                _ = self.add(artworks: panel.urls)
            }
        }
    }

    // MARK: IKImageBrowserDataSource

    override func numberOfItems(inImageBrowser aBrowser: IKImageBrowserView!) -> Int {
        return artworks.count
    }

    override func imageBrowser(_ aBrowser: IKImageBrowserView!, itemAt index: Int) -> Any! {
        return artworks[index].imageValue
    }

    override func imageBrowser(_ aBrowser: IKImageBrowserView!, moveItemsAt indexes: IndexSet!, to destinationIndex: Int) -> Bool {
        let destinationIndex = destinationIndex - indexes.count(in: 0..<destinationIndex)

        let items = indexes.map { artworks[$0] }
        var modifiedArtworks = IndexSet(artworks.indices).subtracting(indexes).map { artworks[$0] }

        for item in items.reversed() {
            modifiedArtworks.insert(item, at: destinationIndex)
        }

        replace(metadataArtworks: artworks, withItems: modifiedArtworks)
        return true
    }

    override func imageBrowser(_ aBrowser: IKImageBrowserView!, writeItemsAt itemIndexes: IndexSet!, to pasteboard: NSPasteboard!) -> Int {
        pasteboard.declareTypes([artworksPBoardType, .tiff], owner: nil)

        for image in itemIndexes.map({ artworks[$0] }).compactMap({ $0.imageValue }) {
            if let representations = image.image?.representations {
                let bitmapData = NSBitmapImageRep.representationOfImageReps(in: representations, using: .tiff, properties: [:])
                pasteboard.setData(bitmapData, forType: .tiff)
            }
            pasteboard.setData(NSKeyedArchiver.archivedData(withRootObject: image), forType: artworksPBoardType)
        }

        return itemIndexes.count
    }

    func paste(to imagebrowserview: ImageBrowserView) {
        let pb = NSPasteboard.general

        if let archivedImageData = pb.data(forType: artworksPBoardType), let image = NSKeyedUnarchiver.unarchiveObject(with: archivedImageData) as? MP42Image {
            _ = add(artworks: [image])
        } else {
            let classes = [NSURL.classForCoder(), NSImage.classForCoder()]
            let options = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: NSImage.imageTypes]
            if let items = pb.readObjects(forClasses: classes, options: options) as [AnyObject]? {
                _ = add(artworks: items)
            }
        }
    }

    override func imageBrowser(_ aBrowser: IKImageBrowserView!, removeItemsAt indexes: IndexSet!) {
        let items = indexes.map { artworks[$0] }
        remove(metadataArtworks: items)
    }

    // MARK: IKImageBrowserDelegate

    override func imageBrowserSelectionDidChange(_ aBrowser: IKImageBrowserView!) {
        let rowIndexes = aBrowser.selectionIndexes()
        removeArtworkButton.isEnabled = rowIndexes?.isEmpty ?? false ? false : true
    }

    @IBAction func zoomSliderDidChange(_ sender: NSControl) {
        artworksView.setZoomValue(sender.floatValue)
    }

    // MARK: Artworks drag & drop

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .generic
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .generic
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard

        let classes = [NSURL.classForCoder(), NSImage.classForCoder()]
        let options = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: NSImage.imageTypes]
        if let items = pb.readObjects(forClasses: classes, options: options) as [AnyObject]? {
            return add(artworks: items)
        } else {
            return false
        }
    }

    func concludeDragOperation(_ sender: NSDraggingInfo?) {}
}
