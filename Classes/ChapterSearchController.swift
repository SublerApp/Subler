//
//  ChapterSearchController.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Cocoa


@objc protocol ChapterSearchControllerDelegate {
    func chapterImportDone(chaptersToBeImported: [MP42TextSample])
}

@objc class ChapterSearchController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet var searchTitle: NSTextField!

    @IBOutlet var resultsTable: NSTableView!
    @IBOutlet var chapterTable: NSTableView!

    @IBOutlet var searchButton: NSButton!
    @IBOutlet var addButton: NSButton!

    @IBOutlet var progress: NSProgressIndicator!
    @IBOutlet var progressText: NSTextField!

    private enum ChapterSearchState {
        case none
        case searching(task: MetadataSearchTask)
        case completed(results: [ChapterResult])
        case closing
    }

    private let delegate: ChapterSearchControllerDelegate
    private let duration: UInt64
    private var searchTerm: String
    private var state: ChapterSearchState
    private var selectedResult: ChapterResult?

    @objc init(delegate: ChapterSearchControllerDelegate, filename: String, duration: UInt64) {
        if let info = filename.parsedAsFilename() {
            switch info {

            case .movie(let title):
                searchTerm = title
            case .tvShow(_,  _,  _):
                searchTerm = filename
            }
        }
        else {
            searchTerm = ""
        }

        self.delegate = delegate
        self.duration = duration
        self.state = .none

        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "SBChapterSearch")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.makeFirstResponder(self.searchTitle)
        updateUI()
    }

    private func searchDone(results: [ChapterResult]) {
        DispatchQueue.main.async {
            self.state = .completed(results: results)
            self.updateUI()
        }
    }

    @IBAction func searchForResults(_ sender: Any) {
        switch state {
        case .none:
            break
        case .searching(let task):
            task.cancel()
        case .completed(_):
            break
        case .closing:
            return
        }

        let task = ChapterSearch.movieSeach(service: ChapterDB(), title: searchTitle.stringValue, duration: duration).search(completionHandler: searchDone)
        state = .searching(task: task)
        _ = task.runAsync()
        updateUI()
    }

    @IBAction func addChapter(_ sender: Any) {
        if let chapters = selectedResult?.chapters {
            var textChapters: [MP42TextSample] = Array()
            for chapter in chapters {
                let sample = MP42TextSample()
                sample.timestamp = chapter.timestamp
                sample.title = chapter.name
                textChapters.append(sample)
            }
            delegate.chapterImportDone(chaptersToBeImported: textChapters)
        }
        self.window?.sheetParent?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
    }

    @IBAction func closeWindow(_ sender: Any) {
        self.window?.sheetParent?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.cancel)
    }

    // MARK - UI state

    private func updateUI() {
        switch state {
        case .none:
            searchButton.isEnabled = true;
            searchButton.keyEquivalent = "\r";
        case .searching(_):
            progress.startAnimation(self)
            progress.isHidden = false
            progressText.stringValue = NSLocalizedString("Searching for chapter information…", comment: "ChapterDB")
            progressText.isHidden = false
            resultsTable.isEnabled = false
            chapterTable.isEnabled = false
            resultsTable.reloadData()
        case .completed(let results):
            if results.count > 0 {
                addButton.isEnabled = true
                addButton.keyEquivalent = "\r"
                searchButton.keyEquivalent = ""
            }
            else {
                searchButton.keyEquivalent = "\r";
                addButton.isEnabled = false
                addButton.keyEquivalent = ""
            }
            progress.stopAnimation(self)
            progress.isHidden = true
            progressText.isHidden = true
            resultsTable.isEnabled = true
            chapterTable.isEnabled = true
            resultsTable.reloadData()
        case .closing:
            return
        }
    }

    // MARK: - Table View

    func tableViewSelectionDidChange(_ notification: Notification) {
        if notification.object as? NSTableView == resultsTable {
            switch state {
            case .none, .searching, .closing:
                selectedResult = nil
            case .completed(let results):
                selectedResult = results[resultsTable.selectedRow]
                chapterTable.reloadData()
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == resultsTable {
            switch state {
            case .completed(let results):
                return results.count
            default:
                return 0
            }
        }
        else if tableView == chapterTable, let result = selectedResult {
            return result.chapters.count
        }
        return 0
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableView == resultsTable {
            switch state {
            case .completed(let results):
                let result = results[row]

                if tableColumn?.identifier.rawValue == "title" {
                    return result.title
                }
                else if tableColumn?.identifier.rawValue == "chaptercount" {
                    return "\(result.chapters.count)".monospacedAttributedString()
                }
                else if tableColumn?.identifier.rawValue == "duration" {
                    return StringFromTime(Int64(result.duration), 1000).monospacedAttributedString()
                }
                else if tableColumn?.identifier.rawValue == "confirmations" {
                    return NSNumber(value: result.confimations)
                }
            default:
                return 0
            }
        }
        else if tableView == chapterTable, let result = selectedResult {
            let chapter = result.chapters[row]

            if tableColumn?.identifier.rawValue == "time" {
                return StringFromTime(Int64(chapter.timestamp), 1000).monospacedAttributedString()
            }
            else if tableColumn?.identifier.rawValue == "name" {
                return chapter.name
            }

        }
        return nil
    }

}
