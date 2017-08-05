//
//  ChapterSearchController.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Cocoa

@objc(SBChapterSearchControllerDelegate) protocol ChapterSearchControllerDelegate {
    func didSelect(chapters: [MP42TextSample])
}

@objc(SBChapterSearchController) class ChapterSearchController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

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
        case completed(results: [ChapterResult], selectedResult: ChapterResult)
    }

    private let delegate: ChapterSearchControllerDelegate
    private let duration: UInt64
    private let searchTerm: String
    private var state: ChapterSearchState

    @objc init(delegate: ChapterSearchControllerDelegate, title: String, duration: UInt64) {
        if let info = title.parsedAsFilename() {
            switch info {

            case .movie(let title):
                searchTerm = title
            case .tvShow(_,  _,  _):
                searchTerm = title
            }
        }
        else {
            searchTerm = title
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

        self.searchTitle.stringValue = searchTerm
        self.window?.makeFirstResponder(self.searchTitle)

        updateUI()

        if searchTerm.count > 0 { searchForResults(self) }
    }

    private func searchDone(results: [ChapterResult]) {
        DispatchQueue.main.async {
            if let first = results.first {
                self.state = .completed(results: results, selectedResult: first)
            }
            else {
                self.state = .none
            }
            self.updateUI()
        }
    }

    @IBAction func searchForResults(_ sender: Any) {
        switch state {
        case .none, .completed:
            break
        case .searching(let task):
            task.cancel()
        }

        let task = ChapterSearch.movieSeach(service: ChapterDB(), title: searchTitle.stringValue, duration: duration)
                                .search(completionHandler: searchDone).runAsync()
        state = .searching(task: task)
        updateUI()
    }

    @IBAction func addChapter(_ sender: Any) {
        switch state {
        case .completed(_, let result):
            var textChapters: [MP42TextSample] = Array()
            for chapter in result.chapters {
                let sample = MP42TextSample()
                sample.timestamp = chapter.timestamp
                sample.title = chapter.name
                textChapters.append(sample)
            }
            delegate.didSelect(chapters: textChapters)
        default:
            break
        }
        self.window?.sheetParent?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
    }

    @IBAction func closeWindow(_ sender: Any) {
        switch state {
        case .searching(let task):
            task.cancel()
        default:
            break
        }
        self.window?.sheetParent?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.cancel)
    }

    // MARK - UI state

    private func startProgressReport() {
        progress.startAnimation(self)
        progress.isHidden = false
        progressText.stringValue = NSLocalizedString("Searching for chapter information…", comment: "ChapterDB")
        progressText.isHidden = false
    }

    private func stopProgressReport() {
        progress.stopAnimation(self)
        progress.isHidden = true
        progressText.isHidden = true
    }

    private func reloadTableData() {
        resultsTable.reloadData()
        chapterTable.reloadData()
    }

    private func swithDefaultButton(from oldDefault: NSButton, to newDefault: NSButton, disableOldButton: Bool) {
        oldDefault.keyEquivalent = ""
        oldDefault.isEnabled = !disableOldButton
        newDefault.keyEquivalent = "\r"
        newDefault.isEnabled = true
    }

    private func updateUI() {
        switch state {
        case .none:
            stopProgressReport()
            reloadTableData()
            swithDefaultButton(from: addButton, to: searchButton, disableOldButton: true)
            updateSearchButtonVisibility()
        case .searching:
            startProgressReport()
            reloadTableData()
            swithDefaultButton(from: addButton, to: searchButton, disableOldButton: true)
        case .completed:
            stopProgressReport()
            reloadTableData()
            swithDefaultButton(from: searchButton, to: addButton, disableOldButton: false)
            window?.makeFirstResponder(resultsTable)
        }
    }

    private func updateSearchButtonVisibility() {
        searchButton.isEnabled = searchTitle.stringValue.count > 0 ? true : false
    }

    override func controlTextDidChange(_ obj: Notification) {
        updateSearchButtonVisibility()
        searchButton.keyEquivalent = "\r"
        addButton.keyEquivalent = ""
    }

    // MARK: - Table View

    func tableViewSelectionDidChange(_ notification: Notification) {
        if notification.object as? NSTableView == resultsTable {
            switch state {
            case .none, .searching:
                break
            case .completed(let results, _):
                state = .completed(results: results, selectedResult: results[resultsTable.selectedRow])
                chapterTable.reloadData()
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == resultsTable {
            switch state {
            case .completed(let results, _):
                return results.count
            default:
                break
            }
        }
        else if tableView == chapterTable {
            switch state {
            case .completed(_, let result):
                return result.chapters.count
            default:
                break
            }
        }
        return 0
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableView == resultsTable {
            switch state {
            case .completed(let results, _):
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
                break
            }
        }
        else if tableView == chapterTable {
            switch state {
            case .completed(_, let result):
                let chapter = result.chapters[row]
                if tableColumn?.identifier.rawValue == "time" {
                    return StringFromTime(Int64(chapter.timestamp), 1000).boldMonospacedAttributedString()
                }
                else if tableColumn?.identifier.rawValue == "name" {
                    return chapter.name
                }
            default:
                break
            }
        }
        return nil
    }

}
