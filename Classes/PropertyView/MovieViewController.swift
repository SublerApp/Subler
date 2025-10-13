//
//  MovieViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 11/03/2019.
//

import Cocoa
import UniformTypeIdentifiers
import MP42Foundation

extension NSPasteboard.PasteboardType {
    static let metadataDragType = NSPasteboard.PasteboardType("org.subler.metadatadragdrop")
    static let artworkDragType = NSPasteboard.PasteboardType("org.subler.artworkdragdrop")
}

class MovieViewController: PropertyView, NSTableViewDataSource, ExpandedTableViewDelegate, NSCollectionViewDataSource, CollectionViewDelegate, NSDraggingDestination, NSFilePromiseProviderDelegate {

    var metadata: MP42Metadata {
        didSet {
            reloadData()
        }
    }

    private var file: MP42File?

    // Metadata tab
    private var tags: [MP42MetadataItem]

    private let ratings: [String]
    private let codes: [String]

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

    // Set save window
    @IBOutlet var saveSetWindow: NSWindow!
    @IBOutlet var saveSetName: NSTextField!
    @IBOutlet var keepArtworks: NSButton!
    @IBOutlet var keepAnnotations: NSButton!

    // Artwork tab
    private var artworks: [MP42MetadataItem]
    private let standardSize = NSSize(width: 280, height: 224)

    @IBOutlet var removeArtworkButton: NSButton!
    @IBOutlet var zoomSlider: NSSlider!
    @IBOutlet var artworksView: CollectionView!

    override var nibName: NSNib.Name? {
        return "MovieView"
    }

    init(mp4: MP42File?, metadata: MP42Metadata) {
        self.file = mp4
        self.metadata = metadata
        self.tags = []
        self.artworks = []

        let selectedCountry = Prefs.ratingsCountry
        let countries = selectedCountry == "All countries" ?
            Ratings.shared.countries :
            Ratings.shared.countries.filter { $0.displayName == selectedCountry || $0.displayName == "USA" }
        self.ratings = countries.flatMap { country in country.ratings
            .map { "\(country.displayName) \($0.media): \($0.displayName)" } }
        self.codes = countries.flatMap { $0.ratings.map { $0.iTunesCode } }

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

        metadataTableView.defaultEditingColumn = 1
        metadataTableView.doubleAction = #selector(doubleClickAction(_:))
        metadataTableView.target = self
        metadataTableView.pasteboardTypes = [.metadataDragType]
        metadataTableView.scrollRowToVisible(0)

        artworksView.register(ArtworkSelectorViewItem.self, forItemWithIdentifier: ArtworkSelectorController.itemView)
        artworksView.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0)})
        artworksView.registerForDraggedTypes([.fileURL, .artworkDragType])
        artworksView.pasteboardTypes = [.fileURL, .tiff, .MP42PasteboardTypeArtwork]

        // Determine the kind of source drag originating from this app.
        // Note, if you want to allow your app to drag items to the Finder's trash can, add ".delete".
        artworksView.setDraggingSourceOperationMask([.copy, .delete], forLocal: false)

        reloadData()
    }

    override func viewWillAppear() {
        let zoomValue = zoomLevel
        setZoomValue(zoomValue)
        zoomSlider.floatValue = zoomValue
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

            if identifier == MP42MetadataKeyHDVideo, let hdType = file?.hdType {
                let item = MP42MetadataItem(identifier: identifier, value: hdType.rawValue as NSCopying & NSObjectProtocol, dataType: MP42MetadataItemDataType.integer, extendedLanguageTag: nil)
                add(metadataItems: [item])
            } else {
                let item = MP42MetadataItem(identifier: identifier, value: "" as NSCopying & NSObjectProtocol, dataType: MP42MetadataItemDataType.unspecified, extendedLanguageTag: nil)
                add(metadataItems: [item])
            }
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

        if let index = self.codes.firstIndex(of: value ?? "") {
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
                    (title: NSLocalizedString("1080p", comment: ""), value: 2),
                    (title: NSLocalizedString("4k", comment: ""), value: 3)]

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
            if #available(macOS 10.14, *) {
                cell?.textField?.textColor = .secondaryLabelColor
            }
            else {
                cell?.textField?.textColor = .disabledControlTextColor
            }
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

    private func stringsArray(fromString string: String) -> [String] {
        let splitElements = ",\\s*+"
        return string.mp42_components(separatedByRegex: splitElements)
    }

    private func numbersArray(fromString string: String) -> [UInt] {
        let parts = string.split(separator: "/")
        var count: UInt = 0, index: UInt = 0

        index = UInt(parts.first ?? "") ?? 0
        if parts.count > 1 {
            count = UInt(parts.last ?? "") ?? 0
        }

        return [index, count]
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
            value = stringsArray(fromString: sender.stringValue)
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
                if index < self.codes.count {
                    value = self.codes[index]
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
        let data = try? NSKeyedArchiver.archivedData(withRootObject: items, requiringSecureCoding: true)
        pb.declareTypes([.string, .metadataDragType], owner: nil)
        pb.setString(description, forType: .string)
        pb.setData(data, forType: .metadataDragType)
    }

    func cutSelection(in tableview: NSTableView) {
        copySelection(in: tableview)
        removeTag(tableview)
    }

    func paste(to tableview: NSTableView) {
        let pb = NSPasteboard.general
        if let archivedData = pb.data(forType: .metadataDragType),
           let data = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.classForCoder(), MP42MetadataItem.classForCoder()], from: archivedData) as? [MP42MetadataItem] {
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
        updateSelection()
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
        updateSelection()
    }

    @IBAction func removeArtwork(_ sender: Any?) {
        remove(metadataArtworks: artworksView.selectionIndexes.map { artworks[$0] })
    }

    private func add(artworks: [Any], toIndexPath: IndexPath) -> Bool {
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
            updateSelection()
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
                _ = self.add(artworks: panel.urls, toIndexPath: IndexPath(index: 0))
            }
        }
    }

    // MARK: - Data source

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return artworks.count
    }

    static let itemView = NSUserInterfaceItemIdentifier(rawValue: "ArtworkSelectorViewItem")

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ArtworkSelectorController.itemView, for: indexPath)
        guard let collectionViewItem = item as? ArtworkSelectorViewItem, let index = indexPath.last else { return item }

        let artwork = artworks[index]

        collectionViewItem.image = artwork.imageValue?.image
        collectionViewItem.title = nil
        collectionViewItem.subtitle = nil
        collectionViewItem.target = self

        return collectionViewItem
    }

    // MARK: - Delegate

    private func updateSelection() {
        removeArtworkButton.isEnabled = artworksView.selectionIndexPaths.isEmpty ? false : true
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }

    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        if let userInfo = filePromiseProvider.userInfo as? [String: AnyObject] {
            return "Artwork." + (userInfo[FilePromiseProvider.UserInfoKeys.extensionKey] as! String)
        } else {
            return "Artwork"
        }
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        if let userInfo = filePromiseProvider.userInfo as? [String: AnyObject] {
            do {
                if let indexPathData = userInfo[FilePromiseProvider.UserInfoKeys.indexPathKey] as? Data {
                    if let indexPath = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(indexPathData) as? IndexPath {
                        let item = artworks[indexPath.last!]
                        if let image = item.imageValue {
                            try image.data?.write(to: url)
                            completionHandler(nil)
                        }
                    }
                }
            } catch {
                fatalError("failed to unarchive indexPath from promise provider.")
            }
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        var provider: NSFilePromiseProvider?

        let item = artworks[indexPath.last!]
        guard let image = item.imageValue else { return provider }

        let fileExtension = {
            switch image.type {
            case MP42_ART_BMP:
                return "bmp"
            case MP42_ART_GIF:
                return "gif"
            case MP42_ART_JPEG:
                return "jpeg"
            case MP42_ART_PNG: fallthrough
            default:
                return "png"
            }
        }()

        if #available(macOS 11.0, *) {
            let typeIdentifier = UTType(filenameExtension: fileExtension)
            provider = FilePromiseProvider(fileType: typeIdentifier!.identifier, delegate: self)
        } else {
            let typeIdentifier =
                  UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)
            provider = FilePromiseProvider(fileType: typeIdentifier!.takeRetainedValue() as String, delegate: self)
        }

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: indexPath, requiringSecureCoding: false)
            provider!.userInfo = [FilePromiseProvider.UserInfoKeys.extensionKey: fileExtension as Any,
                                  FilePromiseProvider.UserInfoKeys.indexPathKey: data]
        } catch {
            fatalError("failed to archive indexPath to pasteboard")
        }
        return provider
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        var dragOperation: NSDragOperation = []

        guard proposedDropOperation.pointee != .on else { return dragOperation }

        let pasteboard = draggingInfo.draggingPasteboard

        if let draggingSource = draggingInfo.draggingSource as? NSCollectionView, draggingSource == collectionView {
            // Drag source came from our own collection view.
            dragOperation = [.move]
        } else {
            // Drag source came from another app.
            // Search through the array of NSPasteboardItems.
            guard let items = pasteboard.pasteboardItems else { return dragOperation }
            for item in items {
                var type: NSPasteboard.PasteboardType
                if #available(macOS 11.0, *) {
                    type = NSPasteboard.PasteboardType(UTType.image.identifier)
                } else {
                    type = (kUTTypeImage as NSPasteboard.PasteboardType)
                }
                if item.availableType(from: [type]) != nil {
                    // Drag source is coming from another app as a promised image file (for example from Photos app).
                    dragOperation = [.copy]
                }
            }
        }

        // Has a drop operation been determined yet?
        if dragOperation == [] {
            // Look for possible URLs you can consume.
            var acceptedTypes: [String]
            if #available(macOS 11.0, *) {
                acceptedTypes = [UTType.image.identifier]
            } else {
                acceptedTypes = [kUTTypeImage as String]
            }

            let options = [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true,
                           NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: acceptedTypes]
                as [NSPasteboard.ReadingOptionKey: Any]
            // Look only for image urls.
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options), !urls.isEmpty {
                // One or more of the URLs in this drag is image file.
                dragOperation = [.copy]
            }
        }
        return dragOperation
    }

    func dropInternalArtworks(_ collectionView: NSCollectionView, draggingInfo: NSDraggingInfo, indexPath: IndexPath) {
        var indexes = Set<IndexPath>()

        draggingInfo.enumerateDraggingItems(
            options: NSDraggingItemEnumerationOptions.concurrent,
            for: collectionView,
            classes: [NSPasteboardItem.self],
            searchOptions: [:],
            using: {(draggingItem, idx, stop) in
                if let pasteboardItem = draggingItem.item as? NSPasteboardItem {
                    do {
                        if let indexPathData = pasteboardItem.data(forType: .artworkDragType),
                           let itemIndexPath = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(indexPathData) as? IndexPath {
                            indexes.insert(itemIndexPath)
                        }
                    } catch {
                        Swift.debugPrint("failed to unarchive indexPath for dropped item.")
                    }
                }
            })

        if let last = indexPath.last {
            let itemIndexes = indexes.compactMap { $0.last }
            let draggedItems = itemIndexes.map { artworks[$0] }
            let destinationIndex = last - itemIndexes.filter { $0 < last }.count

            var modifiedArtworks = IndexSet(artworks.indices).subtracting(IndexSet(itemIndexes)).map { artworks[$0] }

            for item in draggedItems.reversed() {
                modifiedArtworks.insert(item, at: destinationIndex)
            }

            replace(metadataArtworks: artworks, withItems: modifiedArtworks)
        }
    }

    // The temporary directory URL you use to accept file promises.
    lazy var destinationURL: URL = {
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Drops")
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        return destinationURL
    }()

    // Queue you use to read and writing file promises.
    var filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        return queue
    }()

    func handlePromisedDrops(draggingInfo: NSDraggingInfo, toIndexPath: IndexPath) -> Bool {
        var handled = false
        if let promises = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) {
            if !promises.isEmpty {
                for promise in promises {
                    if let promiseReceiver = promise as? NSFilePromiseReceiver {
                        promiseReceiver.receivePromisedFiles(atDestination: destinationURL, options: [:], operationQueue: filePromiseQueue) { fileURL, error in
                            OperationQueue.main.addOperation {
                                if error != nil {
                                    __NSBeep()
                                } else {
                                    _ = self.add(artworks: [fileURL], toIndexPath:toIndexPath)
                                }
                            }
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    // Find the proper drop location relative to the provided indexPath.
    static func dropLocation(indexPath: IndexPath) -> IndexPath {
        var toIndexPath = indexPath
        if indexPath.item == 0 {
            toIndexPath = IndexPath(item: indexPath.item, section: indexPath.section)
        } else {
            toIndexPath = IndexPath(item: indexPath.item - 1, section: indexPath.section)
        }
        return toIndexPath
    }

    func dropExternalArtworks(_ collectionView: NSCollectionView, draggingInfo: NSDraggingInfo, indexPath: IndexPath) {
        let toIndexPath = MovieViewController.dropLocation(indexPath: indexPath)

        if handlePromisedDrops(draggingInfo: draggingInfo, toIndexPath: toIndexPath) {
            // Successfully processed the dragged items that were promised.
        } else {
            // Incoming drag was not promised, so move in all the outside dragged items as URLs.
            var foundNonImageFiles = false

            // Move in all the outside dragged items as URLs.
            draggingInfo.enumerateDraggingItems(
                options: NSDraggingItemEnumerationOptions.concurrent,
                for: collectionView,
                classes: [NSPasteboardItem.self],
                searchOptions: [:],
                using: {(draggingItem, idx, stop) in
                    if let pasteboardItem = draggingItem.item as? NSPasteboardItem,
                       // Are we being passed a file URL as the drag type?
                       let itemType = pasteboardItem.availableType(from: [.fileURL]),
                       let filePath = pasteboardItem.string(forType: itemType),
                       let url = URL(string: filePath) {
                        if !self.add(artworks: [url], toIndexPath:toIndexPath) {
                            foundNonImageFiles = true
                        }
                    }
                })

            if foundNonImageFiles {
                __NSBeep()
            }
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        // Check where the dragged items are coming from.
        if let draggingSource = draggingInfo.draggingSource as? NSCollectionView, draggingSource == collectionView {
            // Drag source from your own collection view.
            // Move each dragged photo item to their new place.
            dropInternalArtworks(collectionView, draggingInfo: draggingInfo, indexPath: indexPath)
        } else {
            // The drop source is from another app (Finder, Mail, Safari, etc.) and there may be more than one file.
            // Drop each dragged image file to their new place.
            dropExternalArtworks(collectionView, draggingInfo: draggingInfo, indexPath: indexPath)
        }
        return true
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        if operation == .delete, let items = session.draggingPasteboard.pasteboardItems {
            // User dragged the artwork to the Finder's trash.
            var indexes = Set<IndexPath>()

            for pasteboardItem in items {
                do {
                    if let indexPathData = pasteboardItem.data(forType: .artworkDragType),
                       let itemIndexPath = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(indexPathData) as? IndexPath {
                        indexes.insert(itemIndexPath)
                    }
                } catch {
                    Swift.debugPrint("failed to unarchive indexPath for dropped item.")
                }
            }

            if indexes.isEmpty == false {
                let itemIndexes = indexes.compactMap { $0.last }
                let draggedItems = itemIndexes.map { artworks[$0] }
                remove(metadataArtworks: draggedItems)
            }
        }
    }

    var zoomLevel: Float {
        get {
            Prefs.movieArtworkSelectorZoomLevel
        }
        set (value) {
            Prefs.movieArtworkSelectorZoomLevel = value;
        }
    }

    private func setZoomValue(_ newZoomValue: Float) {
        if let layout = artworksView.collectionViewLayout as? NSCollectionViewFlowLayout {
            if newZoomValue == 50 {
                layout.itemSize = standardSize
            } else if newZoomValue < 50 {
                let zoomValue = (CGFloat(newZoomValue) + 50) / 100
                layout.itemSize = NSSize(width: Int(standardSize.width * zoomValue),
                                         height: Int(standardSize.height * zoomValue))

            } else {
                let zoomValue = pow((CGFloat(newZoomValue) + 50) / 100, 2.4)
                layout.itemSize = NSSize(width: Int(standardSize.width * zoomValue),
                                         height: Int(standardSize.height * zoomValue))
            }
        }
    }

    @IBAction func zoomSliderDidChange(_ sender: NSControl) {
        setZoomValue(sender.floatValue)
        zoomLevel = sender.floatValue
    }

    func collectionViewDelete(in collectionView: NSCollectionView) {
        removeArtwork(self)
    }

    func collectionViewCopy(in collectionView: NSCollectionView) {
        let indexes = artworksView.selectionIndexes
        if indexes.isEmpty { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let items = indexes.compactMap { artworks[$0].imageValue }
        pasteboard.writeObjects(items)
    }

    func collectionViewPaste(to collectionView: NSCollectionView) {
        let pasteboard = NSPasteboard.general

        let classes = [MP42Image.classForCoder(), NSURL.classForCoder(), NSImage.classForCoder()]
        let options = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: NSImage.imageTypes]

        if let items = pasteboard.readObjects(forClasses: classes, options: options) as [AnyObject]? {
            _ = add(artworks: items, toIndexPath:IndexPath(index: 0))
        }
    }

    func collectionViewCut(in collectionView: NSCollectionView) {
        collectionViewCopy(in: collectionView)
        collectionViewDelete(in: collectionView)
    }

}
