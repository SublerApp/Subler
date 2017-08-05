//
//  ChapterSearchController.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Cocoa

@objc(SBMetadataSearchControllerDelegate) protocol MetadataSearchControllerDelegate {
    func didSelect(metadata: SBMetadataResult)
}

@objc(SBMetadataSearchController) class MetadataSearchController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDelegate, NSComboBoxDataSource, NSTextFieldDelegate, ArtworkSelectorControllerDelegate {

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

    private var tvSeriesNameSearchArray: [String]
    private var nameSearchTask: MetadataSearchTask?

    // MARK: UI State
    private enum MetadataSearchState {
        case none
        case searching(search: MetadataSearch, task: MetadataSearchTask)
        case completed(search: MetadataSearch, results: [SBMetadataResult], selectedResult: SBMetadataResult)
        case additionalSearch(search: MetadataSearch, result: SBMetadataResult, task: MetadataSearchTask)
        case closing(search: MetadataSearch, result: SBMetadataResult)
    }

    private var state: MetadataSearchState

    private var movieService: MetadataService
    private var tvShowService: MetadataService

    // MARK: Other
    private var artworkSelector: ArtworkSelectorController?
    private weak var delegate: MetadataSearchControllerDelegate?
    private let url: URL?

    // MARK: - Static methods
    @objc public static func clearRecentSearches() {
        UserDefaults.standard.removeObject(forKey: "Previously used TV series")
    }

    private static func recentSearches() -> [String] {
        return UserDefaults.standard.array(forKey: "Previously used TV series") as? [String] ?? []
    }

    private static func saveRecentSearches(_ searches: [String]) {
        UserDefaults.standard.set(searches, forKey: "Previously used TV series")
    }

    @objc public static func deleteCachedMetadata() {
        URLCache.shared.removeAllCachedResponses()
    }

    // MARK: - Init
    @objc init(delegate: MetadataSearchControllerDelegate, url: URL?) {
        self.url = url
        self.delegate = delegate
        self.state = .none
        self.movieService = MetadataSearch.defaultMovieService
        self.tvShowService = MetadataSearch.defaultTVService
        self.tvSeriesNameSearchArray = Array()

        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "MetadataSearch")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        movieMetadataProvider.addItems(withTitles: MetadataSearch.movieProviders)
        tvMetadataProvider.addItems(withTitles: MetadataSearch.tvProviders)

        updateLanguagesMenu(service: movieService, popUpButton: movieLanguage)
        updateLanguagesMenu(service: tvShowService, popUpButton: tvLanguage)

        movieMetadataProvider.selectItem(withTitle: movieService.name)
        tvMetadataProvider.selectItem(withTitle: tvShowService.name)

        if let info = url?.lastPathComponent.parsedAsFilename() {
            switch info {
            case let .movie(title):
                searchMode.selectTabViewItem(at: 0)
                movieName.stringValue = title
                searchForResults(searchMovieButton)
            case let .tvShow(seriesName, season, episode):
                searchMode.selectTabViewItem(at: 1)
                tvSeriesName.stringValue = seriesName
                if let season = season { tvSeasonNum.stringValue = "\(season)" }
                if let episode = episode { tvEpisodeNum.stringValue = "\(episode)" }
                searchForResults(searchTvButton)
            }
        }
        else if let title = url?.deletingPathExtension().lastPathComponent {
            movieName.stringValue = title
            tvSeriesName.stringValue = title
            searchForResults(searchMovieButton)
        }
        else {
            updateUI()
        }
    }

    // MARK: - Search UI

    private func updateLanguagesMenu(service: MetadataService, popUpButton: NSPopUpButton) {
        popUpButton.removeAllItems()
        popUpButton.addItems(withTitles: service.languages.map { service.languageType.displayName(language: $0) })

        let type: MetadataSearch.MetadataSearchType = popUpButton == movieLanguage ? .movie : .tvShow

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

            tvSeriesNameSearchArray = [NSLocalizedString("Searching…", comment: "")]

            nameSearchTask = MetadataNameSearch.tvNameSearch(service: TheTVDB(), tvSeries: tvSeriesName.stringValue, language: "en")
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
        //TODO
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
        let searcher = MetadataSearch.tvSearch(service: tvShowService, tvSeries: title, season: season, episode: episode, language: language)
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

    private func searchDone(search: MetadataSearch, results: [SBMetadataResult]) {
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

    private func loadDone(search: MetadataSearch, result: SBMetadataResult) {
        DispatchQueue.main.async {
            self.state = .closing(search: search, result: result)
            if let artworks = result.remoteArtworks, artworks.count > 0 {
                self.selectArtwork(artworks: artworks.toStruct())
            }
            else {
                self.addMetadata()
            }
        }
    }

    private func selectArtwork(artworks: [RemoteImage]) {
        let artworkSelectorController = ArtworkSelectorController(artworks: artworks, delegate: self)
        window?.beginSheet(artworkSelectorController.window!, completionHandler: nil)
        artworkSelector = artworkSelectorController
    }

    func didSelect(artworks: [RemoteImage]) {
        window?.endSheet((artworkSelector?.window)!)
        load(artworks: artworks)
    }

    private func load(artworks: [RemoteImage]) {
        switch state {
        case .closing(_, let result):

            DispatchQueue.global(priority: .background).async {
                for artwork in artworks {
                    if let data = URLSession.data(from: artwork.url) {
                        result.artworks.add(MP42Image(data: data, type: MP42_ART_JPEG))
                    }
                    // Hack, download smaller iTunes version if big iTunes version is not available
                    else if artwork.providerName == iTunesStore().name,
                        let data = URLSession.data(from: artwork.url.deletingPathExtension().appendingPathExtension("600x600bb.jpg")) {
                        result.artworks.add(MP42Image(data: data, type: MP42_ART_JPEG))
                    }
                }
                DispatchQueue.main.async {
                    self.addMetadata()
                }
            }
        default:
            addMetadata()
        }
    }

    private func addMetadata() {
        switch state {
        case .closing(let search, let result):
            if search.type == .tvShow {
                if let title = result[SBMetadataResultSeriesName] as? String {
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
        window?.sheetParent?.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
    }

    @IBAction func closeWindow(_ sender: Any) {
        cancelSearch()
        window?.sheetParent?.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
    }

    // MARK - UI state

    private func startProgressReport() {
        progress.startAnimation(self)
        progress.isHidden = false
        switch state {
        case .searching(let search, _):
            switch search {
            case .movieSeach(let service, _, _):
                progressText.stringValue = NSLocalizedString("Searching \(service.name) for movie information…", comment: "")
            case .tvSearch(let service, _, _ , _, _):
                progressText.stringValue = NSLocalizedString("Searching \(service.name) for episode information…", comment: "")
            }
        case .additionalSearch(let search, _, _):
            switch search {
            case .movieSeach:
                progressText.stringValue = NSLocalizedString("Downloading additional movie metadata", comment: "")
            case .tvSearch:
                progressText.stringValue = NSLocalizedString("Downloading additional TV metadata…", comment: "")
            }
        case .closing:
            progressText.stringValue = NSLocalizedString("Downloading artwork…", comment: "")
        default:
            break
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
        for item in items {
            item.isEnabled = state
        }
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
            window?.makeFirstResponder(resultsTable)
        case .additionalSearch:
            startProgressReport()
            reloadTableData()
            disableUI()
        case .closing:
            startProgressReport()
        }
    }

    private func updateSearchButtonVisibility() {
        if movieName.stringValue.count > 0 {
            searchMovieButton.isEnabled = true
        }
        else {
            searchMovieButton.isEnabled = false
        }
        if tvSeriesName.stringValue.count > 0 {
            if tvSeasonNum.stringValue.count == 0 && tvEpisodeNum.stringValue.count > 0 {
                searchTvButton.isEnabled = false
            } else {
                searchTvButton.isEnabled = true
            }
        }
        else {
            searchTvButton.isEnabled = false
        }
    }

    override func controlTextDidChange(_ obj: Notification) {
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
                return result.tags.count
            default:
                break
            }
        }
        return 0
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableView == resultsTable {
            switch state {
            case .completed(let search, let results, _):
                let result = results[row]
                switch search.type {
                case .tvShow:
                    if let season = result[SBMetadataResultSeason] as? Int,
                        let episode = result[SBMetadataResultEpisodeNumber] as? Int,
                        let title = result[SBMetadataResultName] as? String {
                            return "\(season)x\(episode) - \(title)"
                    }
                case .movie:
                    if let title = result[SBMetadataResultName] as? String {
                        return title
                    }
                }
            default:
                break
            }
        }
        else if tableView == metadataTable {
            switch state {
            case .completed(_, _, let result):
                let key = result.orderedKeys()[row]
                if tableColumn?.identifier.rawValue == "name" {
                    return SBMetadataResult.localizedDisplayName(forKey: key).boldMonospacedAttributedString()
                }
                else if tableColumn?.identifier.rawValue == "value" {
                    return result[key]
                }
            default:
                break
            }
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView.tableColumns.count > 1 {
            let tableColumnToWrap = tableView.tableColumns[1]
            let columnToWrap = tableView.tableColumns.index(of: tableColumnToWrap)
            let cell = tableView.preparedCell(atColumn: columnToWrap!, row: row)!

            let constrainedBounds = NSMakeRect(0, 0, tableColumnToWrap.width, CGFloat.greatestFiniteMagnitude)
            let naturalSize = cell.cellSize(forBounds: constrainedBounds)

            return naturalSize.height > tableView.rowHeight ? naturalSize.height : tableView.rowHeight
        }
        return tableView.rowHeight
    }

}