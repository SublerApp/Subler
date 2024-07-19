//
//  MetadataSearchController.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Cocoa
import MP42Foundation

protocol MetadataSearchControllerDelegate : AnyObject {
    func didSelect(metadata: MetadataResult?)
}

final class MetadataSearchController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDelegate, NSComboBoxDataSource, NSTextFieldDelegate {

    @IBOutlet var searchMode: NSTabView!
    @IBOutlet var movieTab: NSTabViewItem!
    @IBOutlet var tvEpisodeTab: NSTabViewItem!

    // MARK: - Movie
    @IBOutlet var movieName: NSTextField!
    @IBOutlet var movieLanguage: NSPopUpButton!
    @IBOutlet var movieMetadataProvider: NSPopUpButton!

    // MARK: - TV Show
    @IBOutlet var tvSeriesName: NSComboBox!
    @IBOutlet var tvSeasonNum: NSTextField!
    @IBOutlet var tvEpisodeNum: NSTextField!
    @IBOutlet var tvLanguage: NSPopUpButton!
    @IBOutlet var tvMetadataProvider: NSPopUpButton!

    @IBOutlet var searchMovieButton: NSButton!
    @IBOutlet var searchTvButton: NSButton!

    @IBOutlet var resultsTable: NSTableView!
    @IBOutlet var metadataTable: NSTableView!

    @IBOutlet var addButton: NSButton!

    @IBOutlet var progress: NSProgressIndicator!
    @IBOutlet var progressText: NSTextField!

    // MARK: - ComboBox

    private var tvSeriesNameSearchArray: [String] = []
    private var nameSearchTask: Runnable?

    // MARK: UI State
    private enum MetadataSearchState {
        case none
        case searching(search: MetadataSearch, task: Runnable)
        case completed(search: MetadataSearch, results: [MetadataResult], selectedResult: MetadataResult)
        case additionalSearch(search: MetadataSearch, result: MetadataResult, task: Runnable)
        case closing(search: MetadataSearch, result: MetadataResult)
    }

    private var state: MetadataSearchState = .none

    private var movieService: MetadataService = MetadataSearch.defaultMovieService
    private var tvShowService: MetadataService = MetadataSearch.defaultTVService

    // MARK: Other
    private weak var delegate: MetadataSearchControllerDelegate?

    private let terms: MetadataSearchTerms

    // MARK: - Static methods
    public static func clearRecentSearches() {
        UserDefaults.standard.removeObject(forKey: "Previously used TV series")
    }

    private static func recentSearches() -> [String] {
        return UserDefaults.standard.array(forKey: "Previously used TV series") as? [String] ?? []
    }

    private static func saveRecentSearches(_ searches: [String]) {
        UserDefaults.standard.set(searches, forKey: "Previously used TV series")
    }

    public static func deleteCachedMetadata() {
        URLCache.shared.removeAllCachedResponses()
    }

    // MARK: - Init
    init(delegate: MetadataSearchControllerDelegate, searchTerms: MetadataSearchTerms = .none) {
        self.delegate = delegate
        self.terms = searchTerms

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        resultsTable.delegate = nil
        resultsTable.dataSource = nil

        metadataTable.delegate = nil
        metadataTable.dataSource = nil
    }

    override var nibName: NSNib.Name? {
        return "MetadataSearch"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        movieMetadataProvider.addItems(withTitles: MetadataSearch.movieProviders)
        tvMetadataProvider.addItems(withTitles: MetadataSearch.tvProviders)

        updateLanguagesMenu(service: movieService, popUpButton: movieLanguage)
        updateLanguagesMenu(service: tvShowService, popUpButton: tvLanguage)

        movieMetadataProvider.selectItem(withTitle: movieService.name)
        tvMetadataProvider.selectItem(withTitle: tvShowService.name)

        switch terms {
        case .none:
            updateUI()

        case .movie(let title):
            searchMode.selectTabViewItem(at: 0)
            movieName.stringValue = title
            tvSeriesName.stringValue = title
            searchForResults(searchMovieButton)

        case .tvShow(let tvShow, let season, let episode):
            searchMode.selectTabViewItem(at: 1)
            movieName.stringValue = tvShow
            tvSeriesName.stringValue = tvShow
            if let season = season { tvSeasonNum.stringValue = "\(season)" }
            if let episode = episode { tvEpisodeNum.stringValue = "\(episode)" }
            searchForResults(searchTvButton)
        }
    }

    // MARK: - Search UI

    private func updateLanguagesMenu(service: MetadataService, popUpButton: NSPopUpButton) {
        popUpButton.removeAllItems()
        popUpButton.addItems(withTitles: service.languages.map { service.languageType.displayName(language: $0) })

        let type: MetadataType = popUpButton == movieLanguage ? .movie : .tvShow

        popUpButton.selectItem(withTitle: MetadataSearch.defaultLanguage(service: service, type: type))

        if popUpButton.indexOfSelectedItem == -1 {
            popUpButton.selectItem(withTitle: service.languageType.displayName(language: service.defaultLanguage))
        }
    }

    @IBAction func metadataProviderLanguageSelected(_ sender: NSPopUpButton) {
        if sender == movieLanguage, let title = sender.titleOfSelectedItem {
            MetadataSearch.setDefaultLanguage(title, service: movieService, type: .movie)
        }
        else if sender == tvLanguage, let title = sender.titleOfSelectedItem {
            MetadataSearch.setDefaultLanguage(title, service: tvShowService, type: .tvShow)
        }
    }

    @IBAction func metadataProviderSelected(_ sender: NSPopUpButton) {
        if sender == movieMetadataProvider, let title = movieMetadataProvider.selectedItem?.title {
            movieService = MetadataSearch.service(name: title)
            MetadataSearch.defaultMovieService = movieService
            updateLanguagesMenu(service: movieService, popUpButton: movieLanguage)
        }
        else if sender == tvMetadataProvider, let title = tvMetadataProvider.selectedItem?.title {
            tvShowService = MetadataSearch.service(name: title)
            MetadataSearch.defaultTVService = tvShowService
            updateLanguagesMenu(service: tvShowService, popUpButton: tvLanguage)
        }
    }

    // MARK: - Combobox
    func comboBox(_ comboBox: NSComboBox, completedString string: String) -> String? {
        if string.count < 1 { return nil }

        for previousString in MetadataSearchController.recentSearches() {
            if previousString.lowercased().hasPrefix(string.lowercased()) {
                return previousString
            }
        }
        return nil
    }

    func comboBoxWillPopUp(_ notification: Notification) {
        if tvSeriesName.stringValue.count == 0 {
            tvSeriesNameSearchArray = MetadataSearchController.recentSearches().sorted()
        }
        else if tvSeriesName.stringValue.count > 3 {
            if let task = nameSearchTask { task.cancel() }
            let language = tvShowService.languageType.extendedTag(displayName: tvLanguage.titleOfSelectedItem ?? "en")

            tvSeriesNameSearchArray = [NSLocalizedString("Searching…", comment: "")]

            nameSearchTask = MetadataNameSearch.tvNameSearch(service: tvShowService, tvShow: tvSeriesName.stringValue, language: language)
                .search(completionHandler: { (results) in
                DispatchQueue.main.async {
                    self.tvSeriesNameSearchArray = results.sorted()
                    self.tvSeriesName.reloadData()
                    self.nameSearchTask = nil
                }
            }).runAsync()
        }
        else {
            tvSeriesNameSearchArray.removeAll()
        }
        tvSeriesName.reloadData()
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        let index = tvSeriesName.indexOfSelectedItem
        if index > -1, let dataSource = tvSeriesName.dataSource,
            let name = dataSource.comboBox?(tvSeriesName, objectValueForItemAt: index) as? String, name.isEmpty == false {
            tvSeriesName.stringValue = name
            updateSearchButtonVisibility()
        }
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return tvSeriesNameSearchArray.count
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return tvSeriesNameSearchArray[index]
    }

    // MARK: - Search

    @IBAction func searchForResults(_ sender: AnyObject) {
        cancelSearch()
        if (sender === searchMovieButton) {
            searchMovie()
        } else {
            searchTVShow()
        }
        updateUI()
    }

    private func searchMovie() {
        let title = movieName.stringValue
        let language = movieService.languageType.extendedTag(displayName: movieLanguage.titleOfSelectedItem ?? "en")
        let searcher = MetadataSearch.movieSeach(service: movieService, movie: title, language: language)
        let task = searcher.search(completionHandler: { self.searchDone(search: searcher, results: $0) }).runAsync()
        state = .searching(search: searcher, task: task)
    }

    private func searchTVShow() {
        let title = tvSeriesName.stringValue
        let language = tvShowService.languageType.extendedTag(displayName: tvLanguage.titleOfSelectedItem ?? "en")
        let season = Int(tvSeasonNum.stringValue)
        let episode = Int(tvEpisodeNum.stringValue)
        let searcher = MetadataSearch.tvSearch(service: tvShowService, tvShow: title, season: season, episode: episode, language: language)
        let task = searcher.search(completionHandler: { self.searchDone(search: searcher, results: $0) }).runAsync()
        state = .searching(search: searcher, task: task)
    }

    private func cancelSearch() {
        switch state {
        case .searching(_, let task):
            task.cancel()
        case .additionalSearch(_, _, let task):
            task.cancel()
        default:
            break
        }
    }

    private func searchDone(search: MetadataSearch, results: [MetadataResult]) {
        DispatchQueue.main.async {
            if let first = results.first {
                self.state = .completed(search: search, results: results, selectedResult: first)
            }
            else {
                self.state = .none
            }
            self.updateUI()
        }
    }

    @IBAction func loadAdditionalMetadata(_ sender: Any) {
        switch state {
        case .completed(let search, _, let selectedResult):
            let task = search.loadAdditionalMetadata(selectedResult, completionHandler: { self.loadDone(search: search, result: $0) }).runAsync()
            state = .additionalSearch(search: search, result: selectedResult, task: task)
        default:
            break
        }
        updateUI()
    }

    private func loadDone(search: MetadataSearch, result: MetadataResult) {
        DispatchQueue.main.async {
            self.state = .closing(search: search, result: result)
            self.addMetadata()
        }
    }

    private func addMetadata() {
        switch state {
        case .closing(let search, let result):
            if search.type == .tvShow {
                if let title = result[.seriesName] as? String {
                    var previousTVSeries = MetadataSearchController.recentSearches()
                    if previousTVSeries.contains(title) == false {
                        previousTVSeries.append(title)
                    }
                    MetadataSearchController.saveRecentSearches(previousTVSeries)
                }
            }
            delegate?.didSelect(metadata: result)
        default:
            break
        }
    }

    @IBAction func closeWindow(_ sender: Any) {
        cancelSearch()
        delegate?.didSelect(metadata: nil)
    }

    // MARK - UI state

    private func startProgressReport() {
        progress.startAnimation(self)
        progress.isHidden = false
        switch state {
        case .searching(let search, _):
            switch search {
            case .movieSeach(let service, _, _):
                progressText.stringValue = String.localizedStringWithFormat(NSLocalizedString("Searching %@ for movie information…", comment: ""), service.name)
            case .tvSearch(let service, _, _ , _, _):
                progressText.stringValue = String.localizedStringWithFormat(NSLocalizedString("Searching %@ for episode information…", comment: ""), service.name)
            }
        case .additionalSearch(let search, _, _):
            switch search {
            case .movieSeach:
                progressText.stringValue = NSLocalizedString("Downloading additional movie metadata…", comment: "")
            case .tvSearch:
                progressText.stringValue = NSLocalizedString("Downloading additional TV metadata…", comment: "")
            }
        case .closing: break
        default: break
        }
        progressText.isHidden = false
    }

    private func stopProgressReport() {
        progress.stopAnimation(self)
        progress.isHidden = true
        progressText.isHidden = true
    }

    private func reloadTableData() {
        resultsTable.reloadData()
        metadataTable.reloadData()
    }

    private func swithDefaultButton(from oldDefault: NSButton, to newDefault: NSButton, disableOldButton: Bool?) {
        oldDefault.keyEquivalent = ""
        if let disableOldButton = disableOldButton {
            oldDefault.isEnabled = !disableOldButton
        }
        newDefault.keyEquivalent = "\r"
        newDefault.isEnabled = true
    }

    private func toggleUI(items: [NSControl], state: Bool) {
        items.forEach { $0.isEnabled = state }
    }

    private func disableUI() {
        toggleUI(items: [tvSeriesName, tvSeasonNum, tvEpisodeNum, tvLanguage, tvMetadataProvider,
                         movieLanguage, movieMetadataProvider, movieName, addButton,
                         searchTvButton, searchMovieButton, resultsTable, metadataTable],
                 state: false)
    }

    private func visibleSearchButton() -> NSButton {
        return searchMode.selectedTabViewItem == movieTab ? searchMovieButton : searchTvButton
    }

    private func updateUI() {
        switch state {
        case .none:
            stopProgressReport()
            reloadTableData()
            swithDefaultButton(from: addButton, to: visibleSearchButton(), disableOldButton: true)
            updateSearchButtonVisibility()
        case .searching:
            startProgressReport()
            reloadTableData()
            swithDefaultButton(from: addButton, to: visibleSearchButton(), disableOldButton: true)
        case .completed:
            stopProgressReport()
            reloadTableData()
            swithDefaultButton(from: searchMovieButton, to: addButton, disableOldButton: nil)
            swithDefaultButton(from: searchTvButton, to: addButton, disableOldButton: nil)
            updateSearchButtonVisibility()
            view.window?.makeFirstResponder(resultsTable)
        case .additionalSearch:
            startProgressReport()
            reloadTableData()
            disableUI()
        case .closing:
            startProgressReport()
        }
    }

    private func updateSearchButtonVisibility() {
        if movieName.stringValue.isEmpty {
            searchMovieButton.isEnabled = false
        }
        else {
            searchMovieButton.isEnabled = true
        }
        if tvSeriesName.stringValue.isEmpty {
            searchTvButton.isEnabled = false
        }
        else {
            if tvSeasonNum.stringValue.isEmpty && tvEpisodeNum.stringValue.isEmpty == false {
                searchTvButton.isEnabled = false
            } else {
                searchTvButton.isEnabled = true
            }
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        updateSearchButtonVisibility()
        searchMovieButton.keyEquivalent = "\r"
        searchTvButton.keyEquivalent = "\r"
        addButton.keyEquivalent = ""
    }

    // MARK: - Table View

    func tableViewSelectionDidChange(_ notification: Notification) {
        if notification.object as? NSTableView == resultsTable {
            switch state {
            case .none, .searching, .additionalSearch, .closing:
                break
            case .completed(let search, let results, _):
                state = .completed(search: search, results: results, selectedResult: results[resultsTable.selectedRow])
                metadataTable.reloadData()
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == resultsTable {
            switch state {
            case .completed(_, let results, _):
                return results.count
            default:
                break
            }
        }
        else if tableView == metadataTable {
            switch state {
            case .completed(_, _, let result):
                return result.count
            default:
                break
            }
        }
        return 0
    }

    private let resultCell = NSUserInterfaceItemIdentifier(rawValue: "resultCell")
    private let annotationCell = NSUserInterfaceItemIdentifier(rawValue: "annotationCell")
    private let valueCell = NSUserInterfaceItemIdentifier(rawValue: "valueCell")
    private let valueCellForSizing = NSUserInterfaceItemIdentifier(rawValue: "valueCellForSizing")

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == resultsTable {
            let cell = tableView.makeView(withIdentifier: resultCell, owner:self) as? NSTableCellView

            switch state {
            case .completed(let search, let results, _):
                let result = results[row]
                switch search.type {
                case .tvShow:
                    if let season = result[.season] as? Int,
                        let episode = result[.episodeNumber] as? Int {
                        let title = result[.name] as? String ?? NSLocalizedString("Unnamed", comment: "Metadata Search -> Unnamed episode")
                        cell?.textField?.stringValue = "\(season)x\(episode) - \(title)"
                    }
                case .movie:
                    if let title = result[.name] as? String {
                        cell?.textField?.stringValue = title
                    }
                }
                return cell
            default:
                return nil
            }
        }
        else if tableView == metadataTable {

            switch state {
            case .completed(_, _, let result):
                let key = result.orderedKeys[row]
                if tableColumn?.identifier.rawValue == "name" {
                    let cell = tableView.makeView(withIdentifier: annotationCell, owner:self) as? NSTableCellView
                    cell?.textField?.stringValue = key.localizedDisplayName
                    if #available(macOS 10.14, *) {
                        cell?.textField?.textColor = .secondaryLabelColor
                    }
                    else {
                        cell?.textField?.textColor = .disabledControlTextColor
                    }
                    return cell
                }
                else if tableColumn?.identifier.rawValue == "value" {
                    let cell = tableView.makeView(withIdentifier: valueCell, owner:self) as? NSTableCellView
                    cell?.textField?.objectValue = result[key]
                    return cell
                }
            default:
                break
            }

        }
        return nil
    }

    private lazy var dummyCell: NSTableCellView = { return metadataTable.makeView(withIdentifier: valueCellForSizing, owner:self) as? NSTableCellView }()!
    private lazy var dummyCellWidth: NSLayoutConstraint = {
        let constraint = NSLayoutConstraint(item: dummyCell, attribute: NSLayoutConstraint.Attribute.width,
                                            relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil,
                                            attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 500)
        dummyCell.addConstraint(constraint)
        return constraint
    }()

    private static let minHeight = CGFloat(14.0)

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView == metadataTable, case .completed(_, _, let result) = state {
            let column = tableView.tableColumns[1]
            let key = result.orderedKeys[row]
            dummyCell.textField?.stringValue = result[key] as? String ?? ""
            dummyCellWidth.constant = column.width
            dummyCell.textField?.preferredMaxLayoutWidth = column.width - 4

            let height = dummyCell.fittingSize.height
            return height > MetadataSearchController.minHeight ? height : MetadataSearchController.minHeight
        }
        return tableView.rowHeight
    }

}
