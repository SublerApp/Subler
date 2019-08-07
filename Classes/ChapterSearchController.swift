//
//  ChapterSearchController.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Cocoa
import MP42Foundation

protocol ChapterSearchControllerDelegate : AnyObject {
    func didSelect(chapters: [MP42TextSample])
}

final class ChapterSearchController: ViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    @IBOutlet var searchTitle: NSTextField!

    @IBOutlet var resultsTable: NSTableView!
    @IBOutlet var chapterTable: NSTableView!

    @IBOutlet var searchButton: NSButton!
    @IBOutlet var addButton: NSButton!

    @IBOutlet var progress: NSProgressIndicator!
    @IBOutlet var progressText: NSTextField!

    private enum ChapterSearchState {
        case none
        case searching(task: Runnable)
        case completed(results: [ChapterResult], selectedResult: ChapterResult)
    }

    private weak var delegate: ChapterSearchControllerDelegate?
    private let duration: UInt64
    private let searchTerm: String
    private var state: ChapterSearchState

    init(delegate: ChapterSearchControllerDelegate, title: String, duration: UInt64) {
        let info = title.parsedAsFilename()

        switch info {

        case .movie(let title):
            searchTerm = title
        case .tvShow, .none:
            searchTerm = title
        }

        self.delegate = delegate
        self.duration = duration
        self.state = .none

        super.init(nibName: nil, bundle: nil)

        self.autosave = "ChapterSearchControllerAutosaveIdentifier"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        resultsTable.delegate = nil
        resultsTable.dataSource = nil
        chapterTable.delegate = nil
        chapterTable.dataSource = nil
    }

    override var nibName: NSNib.Name? {
        return "SBChapterSearch"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.searchTitle.stringValue = searchTerm
        self.view.window?.makeFirstResponder(self.searchTitle)

        updateUI()

        if searchTerm.isEmpty == false { searchForResults(self) }
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
            var textChapters: [MP42TextSample] = []
            for chapter in result.chapters {
                let sample = MP42TextSample()
                sample.timestamp = chapter.timestamp
                sample.title = chapter.name
                textChapters.append(sample)
            }
            delegate?.didSelect(chapters: textChapters)
        default:
            break
        }
        presentingViewController?.dismiss(self)
    }

    @IBAction func closeWindow(_ sender: Any) {
        switch state {
        case .searching(let task):
            task.cancel()
        default:
            break
        }
        presentingViewController?.dismiss(self)
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
            view.window?.makeFirstResponder(resultsTable)
        }
    }

    private func updateSearchButtonVisibility() {
        searchButton.isEnabled = searchTitle.stringValue.isEmpty ? false : true
    }

    func controlTextDidChange(_ obj: Notification) {
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

    private let titleCell = NSUserInterfaceItemIdentifier(rawValue: "titleCell")
    private let chapterCountCell = NSUserInterfaceItemIdentifier(rawValue: "chapterCountCell")
    private let durationCell = NSUserInterfaceItemIdentifier(rawValue: "durationCell")
    private let confirmationsCell = NSUserInterfaceItemIdentifier(rawValue: "confirmationsCell")

    private let timeCell = NSUserInterfaceItemIdentifier(rawValue: "timeCell")
    private let nameCell = NSUserInterfaceItemIdentifier(rawValue: "nameCell")

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == resultsTable {
            switch state {
            case .completed(let results, _):
                let result = results[row]

                if tableColumn?.identifier.rawValue == "title" {
                    let cell = tableView.makeView(withIdentifier: titleCell, owner:self) as? NSTableCellView
                    cell?.textField?.stringValue = result.title
                    return cell
                }
                else if tableColumn?.identifier.rawValue == "chaptercount" {
                    let cell = tableView.makeView(withIdentifier: titleCell, owner:self) as? NSTableCellView
                    cell?.textField?.attributedStringValue = "\(result.chapters.count)".smallMonospacedAttributedString()
                    return cell
                }
                else if tableColumn?.identifier.rawValue == "duration" {
                    let cell = tableView.makeView(withIdentifier: durationCell, owner:self) as? NSTableCellView
                    cell?.textField?.attributedStringValue = StringFromTime(Int64(result.duration), 1000).smallMonospacedAttributedString()
                    return cell
                }
                else if tableColumn?.identifier.rawValue == "confirmations" {
                    let cell = tableView.makeView(withIdentifier: confirmationsCell, owner:self) as? LevelIndicatorTableCellView
                    cell?.indicator.intValue = Int32(result.confimations)
                    return cell
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
                    let cell = tableView.makeView(withIdentifier: timeCell, owner:self) as? NSTableCellView
                    cell?.textField?.attributedStringValue = StringFromTime(Int64(chapter.timestamp), 1000).boldMonospacedAttributedString()
                    return cell
                }
                else if tableColumn?.identifier.rawValue == "name" {
                    let cell = tableView.makeView(withIdentifier: nameCell, owner:self) as? NSTableCellView
                    cell?.textField?.stringValue = chapter.name
                    return cell
                }
            default:
                break
            }
        }
        return nil
    }

}

/// A NSTableCellView that contains a single level indicator.
class LevelIndicatorTableCellView: NSTableCellView {
    @IBOutlet var indicator: NSLevelIndicator!
}
