//
//  ChapterViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 11/11/2017.
//

import Cocoa
import MP42Foundation

final class ChapterViewController : PropertyView, NSTableViewDataSource, NSTableViewDelegate, ExpandedTableViewDelegate {

    var track: MP42ChapterTrack {
        didSet {
            let indexes = tableView.selectedRowIndexes
            tableView.reloadData()
            if let last = indexes.last, last < track.chapters.count {
                tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            }
        }
    }

    @IBOutlet var tableView: ExpandedTableView!
    @IBOutlet var removeChapter: NSButton!
    @IBOutlet var actions: NSPopUpButton!

    override var nibName: NSNib.Name? {
        return "ChapterView"
    }

    init(track: MP42ChapterTrack) {
        self.track = track
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.defaultEditingColumn = 1
        tableView.doubleAction = #selector(doubleClickAction(_:))

        if #available(macOS 26, *) {
            actions.menu?.items.first?.image = NSImage.init(systemSymbolName: "ellipsis", accessibilityDescription: nil)
        }
    }

    // MARK: Table View

    func numberOfRows(in tableView: NSTableView) -> Int {
        return Int(track.chapterCount())
    }

    let trackTimeColumn = NSUserInterfaceItemIdentifier(rawValue: "time")
    let trackTitleColumn = NSUserInterfaceItemIdentifier(rawValue: "title")

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let chapter = track.chapter(at: UInt(row))
        switch tableColumn?.identifier {

        case trackTimeColumn?:
            let cell = tableView.makeView(withIdentifier: trackTimeColumn, owner:self) as? NSTableCellView
            cell?.textField?.attributedStringValue = StringFromTime(Int64(chapter.timestamp), 1000).boldMonospacedAttributedString()
            return cell

        case trackTitleColumn?:
            let cell = tableView.makeView(withIdentifier: trackTitleColumn, owner:self) as? NSTableCellView
            cell?.textField?.stringValue = chapter.title
            return cell

        default:
            return nil
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeChapter.isEnabled =  tableView.selectedRow != -1 ? true : false
    }

    @IBAction func setChapterTitle(_ sender: NSTextField) {
        let row = tableView.row(for: sender)
        if row > -1 {
            let chapter = track.chapter(at: UInt(row))
            track.setTitle(sender.stringValue, forChapter: chapter)

            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 1))
        }
    }

    @IBAction func setChapterTimeStamp(_ sender: NSTextField) {
        let row = tableView.row(for: sender)
        if row > -1 {
            let chapter = track.chapter(at: UInt(row))
            let timestamp = TimeFromString(sender.stringValue, 1000)
            track.setTimestamp(timestamp, forChapter: chapter)

            tableView.reloadData()
        }
    }

    @IBAction func doubleClickAction(_ sender: NSTableView) {
        if sender.clickedRow > -1 && sender.clickedColumn > -1 {
            sender.editColumn(sender.clickedColumn, row: sender.clickedRow, with: nil, select: true)
        }
    }

    func deleteSelection(in tableview: NSTableView) {
        let indexes = tableView.selectedRowIndexes
        if indexes.isEmpty == false {
            track.removeChapters(at: indexes)
            tableView.removeRows(at: indexes, withAnimation: NSTableView.AnimationOptions.slideUp)
            if let index = indexes.first, index < track.chapters.count {
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            }
        }
    }

    // MARK: Actions

    @IBAction func removeChapter(_ sender: Any) {
        deleteSelection(in: tableView)
    }

    @IBAction func addChapter(_ sender: Any) {
        let index = track.addChapter("Chapter", timestamp: 0)
        let indexSet = IndexSet(integer: Int(index))
        tableView.insertRows(at: indexSet, withAnimation: .slideDown)
        tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
        view.window?.makeFirstResponder(tableView)
    }

    @IBAction func renameChapters(_ sender: Any) {
        for (index, chapter) in track.chapters.enumerated() {
            let title = "Chapter \(index + 1)"
            track.setTitle(title, forChapter: chapter)
        }
        tableView.reloadData()
    }

}
