//
//  TracksViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 03/02/2018.
//

import Cocoa
import MP42Foundation

protocol TracksViewControllerDelegate: AnyObject {
    @MainActor func didSelect(tracks: [MP42Track])
    @MainActor func delete(tracks: [MP42Track])
}

final class TracksViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, ExpandedTableViewDelegate {

    weak var delegate: TracksViewControllerDelegate?

    private let document: Document

    var mp4: MP42File {
        didSet {
            let selectedIndexes = tracksTable.selectedRowIndexes
            reloadData()
            if let max = selectedIndexes.max(), mp4.tracks.count >= max {
                tracksTable.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
            }
        }
    }

    @IBOutlet var tracksTable: ExpandedTableView!
    private let pasteboardType = NSPasteboard.PasteboardType(rawValue: "SublerTableViewDataType")

    private static let languagesMenu: NSMenu = {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for title in MP42Languages.defaultManager.localizedExtendedLanguages {
            menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
        }

        return menu
    }()

    override var nibName: NSNib.Name? {
        return "TracksViewController"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tracksTable.registerForDraggedTypes([pasteboardType])
        tracksTable.doubleAction = #selector(doubleClickAction)
        tracksTable.scrollRowToVisible(0)
    }

    init(document: Document, delegate: TracksViewControllerDelegate) {
        self.document = document;
        self.mp4 = document.mp4
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadData() {
        tracksTable.reloadData()
        delegate?.didSelect(tracks: selectedTracks)
    }

    var selectedTracks: [MP42Track] {
        return tracksTable != nil ? tracksTable.selectedRowIndexes.compactMap { track(at: $0) } : []
    }

    // MARK: Delegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        delegate?.didSelect(tracks: selectedTracks)
    }

    @IBAction func doubleClickAction(_ sender: NSTableView) {
        // make sure they clicked a real cell and not a header or empty row
        if sender.clickedRow >= 1 {
            let column = sender.tableColumns[sender.clickedColumn]
            if column.identifier == trackNameColumn {
                sender.editColumn(sender.clickedColumn, row: sender.clickedRow, with: nil, select: true)
            }
        }
    }

    func deleteSelection(in tableview: NSTableView) {
        delegate?.delete(tracks: selectedTracks)
    }

    // MARK: Actions

    @IBAction func setTrackEnabled(_ sender: NSButton) {
        let row = tracksTable.row(for: sender)
        if let track = track(at: row) {
            track.isEnabled = sender.state == NSControl.StateValue.on ? true : false
            document.updateChangeCount(.changeDone)
        }
    }

    @IBAction func setTrackName(_ sender: NSTextField) {
        let row = tracksTable.row(for: sender)
        if let track = track(at: row), track.name != sender.stringValue {
            track.name = sender.stringValue
            document.updateChangeCount(.changeDone)
            let column = tracksTable.column(for: sender)
            tracksTable.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: column))
        }
    }

    @IBAction func setTrackLanguage(_ sender: NSPopUpButton) {
        let manager = MP42Languages.defaultManager
        let row = tracksTable.row(for: sender)
        let index = sender.indexOfSelectedItem
        var language = sender.selectedItem?.title

        if index >= 0 && index < manager.localizedExtendedLanguages.count {
            let localizedLanguage = MP42Languages.defaultManager.localizedExtendedLanguages[sender.indexOfSelectedItem]
            language = MP42Languages.defaultManager.extendedTag(forLocalizedLang: localizedLanguage)
        }

        if let track = track(at: row), track.language != language {
            track.language = language ?? "und"
            document.updateChangeCount(.changeDone)
        }
    }

    // MARK: Data source

    private let trackIdColumn = NSUserInterfaceItemIdentifier(rawValue: "trackId")
    private let trackEnabledColumn = NSUserInterfaceItemIdentifier(rawValue: "trackEnabled")
    private let trackNameColumn = NSUserInterfaceItemIdentifier(rawValue: "trackName")
    private let trackDurationColumn = NSUserInterfaceItemIdentifier(rawValue: "trackDuration")
    private let trackLanguageColumn = NSUserInterfaceItemIdentifier(rawValue: "trackLanguage")
    private let trackInfoColumn = NSUserInterfaceItemIdentifier(rawValue: "trackInfo")

    private let disabledIdCell = NSUserInterfaceItemIdentifier(rawValue: "disabledIdCell")
    private let disabledFormatCell = NSUserInterfaceItemIdentifier(rawValue: "DisabledFormatCell")

    private func track(at row: Int) -> MP42Track? {
        return row <= 0 ? nil : mp4.track(at: UInt(row - 1))
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return mp4.tracks.count + 1
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        if let track = track(at: row) {

            switch tableColumn?.identifier {

            case trackIdColumn?:
                let cell = tableView.makeView(withIdentifier: trackIdColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = track.trackId == 0 ? NSLocalizedString("na", comment: "") : String(track.trackId)
                return cell

            case trackEnabledColumn?:
                let cell = tableView.makeView(withIdentifier: trackEnabledColumn, owner:self) as? CheckBoxCellView
                cell?.checkboxButton?.state = track.isEnabled ? NSControl.StateValue.on : NSControl.StateValue.off
                return cell

            case trackNameColumn?:
                let cell = tableView.makeView(withIdentifier: trackNameColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = track.name
                cell?.textField?.isEditable = true
                return cell

            case trackDurationColumn?:
                let cell = tableView.makeView(withIdentifier: trackDurationColumn, owner:self) as? NSTableCellView
                cell?.textField?.attributedStringValue = StringFromTime(Int64(track.duration), 1000).monospacedAttributedString()
                return cell

            case trackLanguageColumn?:
                let cell = tableView.makeView(withIdentifier: trackLanguageColumn, owner:self) as? PopUpCellView

                if (cell?.popUpButton.numberOfItems == 0) {
                    cell?.popUpButton.menu = TracksViewController.languagesMenu.copy() as? NSMenu
                }

                cell?.popUpButton.selectItem(withTitle: MP42Languages.defaultManager.localizedLang(forExtendedTag: track.language))

                if (cell?.popUpButton.indexOfSelectedItem == -1) {
                    cell?.popUpButton.addItem(withTitle: track.language)
                    cell?.popUpButton.selectItem(withTitle: track.language)
                }

                cell?.textField?.stringValue = MP42Languages.defaultManager.localizedLang(forExtendedTag: track.language)
                return cell

            case trackInfoColumn?:
                let cell = tableView.makeView(withIdentifier: trackInfoColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = track.formatSummary
                return cell

            default:
                return nil
            }

        }
        else {
            switch tableColumn?.identifier {

            case trackIdColumn?:
                let cell = tableView.makeView(withIdentifier: disabledIdCell, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = "-"
                return cell

            case trackNameColumn?:
                let cell = tableView.makeView(withIdentifier: trackNameColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = NSLocalizedString("Metadata", comment: "")
                cell?.textField?.isEditable = false
                return cell

            case trackDurationColumn?:
                let cell = tableView.makeView(withIdentifier: trackDurationColumn, owner:self) as? NSTableCellView
                cell?.textField?.attributedStringValue = StringFromTime(Int64(mp4.duration), 1000).monospacedAttributedString()
                return cell

            case trackLanguageColumn?:
                let cell = tableView.makeView(withIdentifier: disabledFormatCell, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = NSLocalizedString("-NA-", comment: "")
                return cell

            case trackInfoColumn?:
                let cell = tableView.makeView(withIdentifier: disabledFormatCell, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = NSLocalizedString("-NA-", comment: "")
                return cell

            default:
                return nil
            }

        }
    }

    // MARK: Drag & drop

    func tableView(_ tableView: NSTableView,
                   writeRowsWith rowIndexes: IndexSet,
                   to pboard: NSPasteboard) -> Bool {
        guard let firstRow = rowIndexes.first,
            let track = track(at: firstRow), track.isMuxed == false
            else { return false }

        let data = try? NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: true)
        pboard.declareTypes([pasteboardType], owner: self)
        pboard.setData(data, forType: pasteboardType)
        return true
    }

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation: NSTableView.DropOperation) -> NSDragOperation {
        let count = mp4.tracks.count + 1

        if proposedDropOperation == .above {
            if row < count && row != 0, let track = track(at: row), track.isMuxed == false {
                return .every
            }
            else if row == count {
                return .every
            }
        }
        return []
    }

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        let data: Data = info.draggingPasteboard.data(forType: pasteboardType)!
        if let rowIndexes: IndexSet = NSKeyedUnarchiver.unarchiveObject(with: data) as? IndexSet, rowIndexes.isEmpty == false {

            let tracks = mp4.tracks.enumerated().filter { rowIndexes.contains($0.offset + 1)} .map { $0.element }
            mp4.moveTracks(tracks, to: UInt(row - 1))

            tableView.reloadData()
            return true
        }

        return false
    }
}
