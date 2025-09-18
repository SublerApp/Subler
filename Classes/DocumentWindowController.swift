//
//  DocumentWindowController.swift
//  Subler
//
//  Created by Damiano Galassi on 03/02/2018.
//

import Cocoa
import MP42Foundation

final class DocumentWindowController: NSWindowController, TracksViewControllerDelegate, MetadataSearchViewControllerDelegate, FileImportControllerDelegate, ProgressViewControllerDelegate, NSDraggingDestination, NSUserInterfaceValidations {

    private var doc: Document {
        return document as! Document
    }

    private var mp4: MP42File {
        return doc.mp4
    }

    override var windowNibName: NSNib.Name? {
        return "DocumentWindowController"
    }

    init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let toolbarDelegate = DocumentToolbarDelegate()

    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window = window else {
            fatalError("`window` is expected to be non nil by this time.")
        }

        if #available(macOS 11, *) {
            window.toolbarStyle = .expanded
        }

        toolbarDelegate.target = self

        let toolbar = NSToolbar(identifier: "SublerDocumentToolbar")
        toolbar.delegate = toolbarDelegate
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        if #available(macOS 26, *) {
            toolbar.displayMode = .iconAndLabel
        } else {
            toolbar.displayMode = .iconOnly
        }
        self.window?.toolbar = toolbar

        window.contentViewController = splitViewController
        window.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])

        if Prefs.rememberDocumentWindowSize {
            window.setFrameAutosaveName("documentSave")
            window.setFrame(from: "documentSave")

            splitViewController.splitView.autosaveName = DocumentWindowController.splitViewResorationAutosaveName
            splitViewController.splitView.identifier = DocumentWindowController.splitViewResorationIdentifier
        }
        else {
            window.setContentSize(NSSize(width: 690, height: 510))
            splitViewController.splitView.setPosition(160, ofDividerAt: 0)
        }

        didSelect(tracks: [])
    }

    private static let splitViewResorationIdentifier = NSUserInterfaceItemIdentifier(rawValue: "splitViewSave")
    private static let splitViewResorationAutosaveName = "splitViewSave"

    private lazy var splitViewController: NSSplitViewController = {
        // Create a split view controller to contain split view items.
        let splitViewController = NSSplitViewController()
        splitViewController.view.wantsLayer = true
        splitViewController.splitView.isVertical = false
        splitViewController.splitView.dividerStyle = NSSplitView.DividerStyle.thick

        let tracksSplitViewItem = NSSplitViewItem(viewController: tracksViewController)
        tracksSplitViewItem.minimumThickness = 100

        splitViewController.addSplitViewItem(tracksSplitViewItem)

        let detailsSplitViewItem = NSSplitViewItem(viewController: DetailsViewController())
        detailsSplitViewItem.canCollapse = true
        detailsSplitViewItem.minimumThickness = 320

        splitViewController.addSplitViewItem(detailsSplitViewItem)

        return splitViewController
    }()

    private lazy var tracksViewController: TracksViewController = {
        let tracksViewController = TracksViewController(document: doc, delegate: self)
        return tracksViewController
    }()

    private var metadataViewController: MovieViewController?
    private var videoViewController: VideoViewController?
    private var soundViewController: SoundViewController?
    private var chapterViewController: ChapterViewController?
    private var multiViewController: MultiSelectViewController?
    private var emptyViewController: EmptyViewController?

    private var selectedTabIndexesDict: [String:Int] = [:]

    private func saveTabIndex(_ propertyView: PropertyView?) {
        if let propertyView {
            selectedTabIndexesDict[String(describing: type(of: propertyView))] =  propertyView.selectedViewIndex()
        }
    }

    private func selectTabViewItem(for propertyView: PropertyView) {
        let key = String(describing: type(of: propertyView))
        if let tabIndex = selectedTabIndexesDict[key] {
            propertyView.selectTabViewItem(at: tabIndex)
            selectedTabIndexesDict.removeValue(forKey: key)
        }
    }

    private func clearDetailsViewControllers() {
        saveTabIndex(metadataViewController)
        metadataViewController = nil
        saveTabIndex(videoViewController)
        videoViewController = nil
        saveTabIndex(soundViewController)
        soundViewController = nil
        chapterViewController = nil
        multiViewController = nil
    }

    private func detailsViewController(_ tracks: [MP42Track]) -> PropertyView {
        if tracks.count > 1 {
            let controller = MultiSelectViewController(numberOfTracks: UInt(tracks.count))
            return controller
        } else {
            switch tracks.first {

            case let track as MP42VideoTrack:
                if let videoViewController = videoViewController {
                    videoViewController.track = track
                } else {
                    videoViewController = VideoViewController(mp4: mp4, track: track)
                }
                return videoViewController!

            case let track as MP42AudioTrack:
                if let soundViewController = soundViewController {
                    soundViewController.track = track
                } else {
                    soundViewController = SoundViewController(mp4: mp4, track: track)
                }
                return soundViewController!

            case let track as MP42ChapterTrack:
                if let chapterViewController = chapterViewController {
                    chapterViewController.track = track
                } else {
                    chapterViewController = ChapterViewController(track: track)
                }
                return chapterViewController!

            case let track where track != nil:
                if emptyViewController == nil {
                    emptyViewController = EmptyViewController()
                }
                return emptyViewController!

            default:
                if metadataViewController == nil {
                    metadataViewController = MovieViewController(mp4: mp4, metadata: mp4.metadata)
                }
                return metadataViewController!
            }
        }
    }

    func reloadData() {
        clearDetailsViewControllers()
        tracksViewController.mp4 = doc.mp4
    }

    // MARK: Tracks controller delegate

    func didSelect(tracks: [MP42Track]) {
        let detailsItem = splitViewController.splitViewItems[1]
        if let detailsViewController = detailsItem.viewController.children.first {
            doc.undoManager?.removeAllActions(withTarget: detailsViewController)
            detailsViewController.view.removeFromSuperviewWithoutNeedingDisplay()
            detailsItem.viewController.removeChild(at: 0)
        }

        let trackViewController = detailsViewController(tracks)
        detailsItem.viewController.addChild(trackViewController)
        trackViewController.view.frame = detailsItem.viewController.view.bounds
        trackViewController.view.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        detailsItem.viewController.view.addSubview(trackViewController.view)

        selectTabViewItem(for: trackViewController)
    }

    func delete(tracks: [MP42Track]) {
        if tracks.isEmpty == false {
            mp4.removeTracks(tracks)

            if Prefs.organizeAlternateGroups { mp4.organizeAlternateGroups() }
            if Prefs.inferMediaCharacteristics { mp4.inferMediaCharacteristics() }

            doc.updateChangeCount(.changeDone)
            tracksViewController.reloadData()
        }
    }

    // MARK: Validation

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {

        case #selector(selectFile(_:)),
             #selector(selectMetadataFile(_:)),
             #selector(searchMetadata(_:)),
             #selector(addChaptersEvery(_:)),
             #selector(iTunesFriendlyTrackGroups(_:)),
             #selector(clearTrackNames(_:)),
             #selector(prettifyAudioTrackNames(_:)),
             #selector(fixAudioFallbacks(_:)),
             #selector(sendToQueue(_:)):
            return true

        case #selector(sendToExternalApp(_:)) where mp4.hasFileRepresentation && doc.isDocumentEdited == false:
            return true

        case #selector(showTrackOffsetSheet(_:)) where tracksViewController.selectedTracks.isEmpty == false:
            return true

        case #selector(export(_:)) where tracksViewController.selectedTracks.isEmpty == false:
            if let track = tracksViewController.selectedTracks.first, track.isMuxed, track.canExport {
                return true
            } else {
                return false
            }

        case #selector(DocumentWindowController.deleteTrack(_:)):
            return tracksViewController.selectedTracks.isEmpty == false && NSApp.isActive

        default:
            return false
        }
    }

    // MARK: Save status

    private var progressController: ProgressViewController?

    func startProgressReporting() {
        let progressController = ProgressViewController()
        progressController.delegate = self
        contentViewController?.presentAsSheet(progressController)
        self.progressController = progressController
        mp4.progressHandler = { [weak progressController] progress in
            DispatchQueue.main.async {
                guard let progressController = progressController else { return }
                progressController.progress = progress
            }
        }
    }

    func setProgress(title: String) {
        if let progressController = self.progressController {
            progressController.progressTitle = title
        }
    }

    func endProgressReporting() {
        mp4.progressHandler = nil
        if let progressController = self.progressController {
            contentViewController?.dismiss(progressController)
            self.progressController = nil
        }
    }

    func cancelSave() {
        doc.cancelSave()
    }

    // MARK: Actions

    @IBAction func sendToQueue(_ sender: Any) {
        doc.sendToQueue(self)
    }

    @IBAction func sendToExternalApp(_ sender: Any) {
        if let fileURL = doc.fileURL {
            _ = sendToFileExternalApp(fileURL: fileURL)
        }
    }

    @IBAction func deleteTrack(_ sender: Any) {
        delete(tracks: tracksViewController.selectedTracks)
    }

    @IBAction func addChaptersEvery(_ sender: NSMenuItem) {
        let track: MP42ChapterTrack = mp4.chapters ?? { let track = MP42ChapterTrack(); self.mp4.addTrack(track); return track }()
        let minutes = sender.tag * 60 * 1000

        if minutes > 0 {
            for (index, timestamp) in stride(from: 0, to: mp4.duration, by: minutes).enumerated() {
                track.addChapter("Chapter \(index + 1)", timestamp: UInt64(timestamp))
            }
        }
        else {
            track.addChapter("Chapter 1", timestamp: 0)
        }

        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
    }

    @IBAction func iTunesFriendlyTrackGroups(_ sender: Any) {
        mp4.organizeAlternateGroups()
        mp4.inferTracksLanguages()
        mp4.inferMediaCharacteristics()

        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
    }

    @IBAction func clearTrackNames(_ sender: Any) {
        for track in mp4.tracks {
            track.name = ""
        }

        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
    }

    @IBAction func prettifyAudioTrackNames(_ sender: Any) {

        for track in mp4.tracks.compactMap({ $0 as? MP42AudioTrack }) {
            track.name = track.prettyTrackName
        }

        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
    }

    @IBAction func fixAudioFallbacks(_ sender: Any) {
        mp4.setAutoFallback()
        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
    }

    @IBAction func showTrackOffsetSheet(_ sender: Any) {
        guard let track = tracksViewController.selectedTracks.first else { return }
        let controller = OffsetViewController(doc: doc, track: track)
        self.window?.contentViewController?.presentAsSheet(controller)
    }

    @IBAction func export(_ sender: Any) {
        guard let fileName = doc.fileURL?.deletingPathExtension().lastPathComponent,
            let track = tracksViewController.selectedTracks.first,
            let windowForSheet = doc.windowForSheet
        else { return }

        let ext = (track as? MP42SubtitleTrack) != nil ? "srt" : "txt"

        let panel = NSSavePanel()
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = "\(fileName).\(track.trackId).\(track.language).\(ext)"

        panel.beginSheetModal(for: windowForSheet) { (response) in
            if response == NSApplication.ModalResponse.OK, let url = panel.url {
                do {
                    try track.export(to: url)
                } catch {
                    let alert = NSAlert()
                    alert.addButton(withTitle: NSLocalizedString("OK", comment: "Export alert panel -> button"))
                    alert.messageText = NSLocalizedString("File Could Not Be Saved", comment: "Export alert panel -> title")
                    alert.informativeText = NSLocalizedString("There was a problem creating the file ", comment: "Export alert panel -> message") + url.lastPathComponent + "."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    // MARK: Metadata

    @IBAction func searchMetadata(_ sender: Any?) {
        let terms = mp4.extractSearchTerms(fallbackURL : doc.fileURL)
        let controller = MetadataSearchViewController(delegate: self, searchTerms: terms)
        self.contentViewController?.presentAsSheet(controller)
    }

    func didSelect(metadata: MetadataResult) {
        let map = metadata.mediaKind == .movie ? MetadataPrefs.movieResultMap : MetadataPrefs.tvShowResultMap
        let keepEmptyKeys = MetadataPrefs.keepEmptyAnnotations

        let result = metadata.mappedMetadata(to: map, keepEmptyKeys: keepEmptyKeys)
        mp4.metadata.merge(result)

        if let hdType = mp4.hdType {
            for item in mp4.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyHDVideo) {
                mp4.metadata.removeItem(item)
            }
            mp4.metadata.addItem(MP42MetadataItem(identifier: MP42MetadataKeyHDVideo, value: NSNumber(value: hdType.rawValue),
                                                  dataType: .integer, extendedLanguageTag: nil))
        }
        doc.updateChangeCount(.changeDone)
        metadataViewController?.metadata = mp4.metadata
    }

    // MARK: File import

    private func addChapters(fileURL: URL) {
        mp4.addTrack(MP42ChapterTrack(fromFile: fileURL))

        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
    }

    private func updateChapters(fileURL: URL) {
        do {
            try mp4.chapters?.update(fromCSVFile: fileURL)
            doc.updateChangeCount(.changeDone)
            if let track = mp4.chapters {
                chapterViewController?.track = track
            }
        }
        catch {
            if let windowForSheet = doc.windowForSheet {
                presentError(error, modalFor: windowForSheet, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                presentError(error)
            }
        }
    }

    private func addMetadata(fileURL: URL) {
        let ext = fileURL.pathExtension.lowercased()
        if ext == "xml" || ext == "nfo", let metadata = MP42Metadata(url: fileURL) {
            mp4.metadata.merge(metadata)
            doc.updateChangeCount(.changeDone)
            metadataViewController?.metadata = mp4.metadata
        } else if let file = try? MP42File(url: fileURL) {
            mp4.metadata.merge(file.metadata)
            doc.updateChangeCount(.changeDone)
            metadataViewController?.metadata = mp4.metadata
        }
    }

    @IBAction func selectMetadataFile(_ sender: Any) {
        guard let windowForSheet = doc.windowForSheet else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["mp4", "m4v", "m4a", "xml", "nfo"]

        panel.beginSheetModal(for: windowForSheet) { (response) in
            if response == NSApplication.ModalResponse.OK, let url = panel.url {
                self.addMetadata(fileURL: url)
            }
        }
    }

    @IBAction func selectFile(_ sender: Any) {
        guard let windowForSheet = doc.windowForSheet else { return }
        let supportedFileFormats = MP42FileImporter.supportedFileFormats() + ["txt", "csv"]

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = supportedFileFormats

        panel.beginSheetModal(for: windowForSheet) { (response) in
            if response == NSApplication.ModalResponse.OK {
                let ext = panel.url?.pathExtension.lowercased()
                if ext == "txt", let url = panel.url {
                    self.addChapters(fileURL: url)
                }
                else if ext == "csv", let url = panel.url {
                    self.updateChapters(fileURL: url)
                }
                else {
                    self.showImportSheet(fileURLs: panel.urls)
                }
            }
        }
    }

    func showImportSheet(fileURLs: [URL]) {
        do {
            let controller = try FileImportController(fileURLs: fileURLs, delegate: self)

            if controller.onlyContainsSubtitles {
                controller.addTracks(self)
                tracksViewController.reloadData()
            } else {
                contentViewController?.presentAsSheet(controller)
            }
        }
        catch {
            if let windowForSheet = doc.windowForSheet {
                presentError(error, modalFor: windowForSheet, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                presentError(error)
            }
        }
    }

    @objc func importFilesDirectly(_ fileURLs: [URL]) {
        do {
            let controller = try FileImportController(fileURLs: fileURLs, delegate: self)

            // Call addTracks directly - the Settings initialization logic runs when the controller is created
            controller.addTracks(self)
            tracksViewController.reloadData()
        } catch {
            if let windowForSheet = doc.windowForSheet {
                presentError(error, modalFor: windowForSheet, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                presentError(error)
            }
        }
    }

    func didSelect(tracks: [MP42Track], metadata: MP42Metadata?) {
        for track in tracks {
            mp4.addTrack(track)
        }

        if tracks.isEmpty == false {
            doc.updateChangeCount(.changeDone)

            if Prefs.organizeAlternateGroups {
                mp4.organizeAlternateGroups()
                if Prefs.inferMediaCharacteristics {
                    mp4.inferTracksLanguages()
                    mp4.inferMediaCharacteristics()
                }
            }
        }

        if let metadata = metadata {
            mp4.metadata.merge(metadata)
            doc.updateChangeCount(.changeDone)
            metadataViewController?.metadata = mp4.metadata
        }

        tracksViewController.reloadData()
    }

    // MARK: Drag & drop

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard.types,
            types.contains(NSPasteboard.PasteboardType.fileURL) &&
                sender.draggingSourceOperationMask.contains(.copy)
        else { return [] }

        return .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let types = pasteboard.types,
            types.contains(NSPasteboard.PasteboardType.fileURL),
            let items = pasteboard.readObjects(forClasses: [NSURL.classForCoder()], options: [:]) as? [URL]
            else { return false }

        let chapters = items.filter { $0.pathExtension.lowercased() == "txt" }
        if let url = chapters.first {
            addChapters(fileURL: url)
        }

        let metadata = items.filter { let ext = $0.pathExtension.lowercased(); return ext == "xml" ||  ext == "nfo" }
        if let url = metadata.first {
            addMetadata(fileURL: url)
        }

        let files = items.filter { MP42FileImporter.canInit(withFileType: $0.pathExtension) }
        if files.isEmpty == false {
            showImportSheet(fileURLs: files)
        }

        return true
    }

    // MARK: Keyboard navigation

    override func keyDown(with event: NSEvent) {
        guard let key = event.charactersIgnoringModifiers?.utf16.first else { super.keyDown(with: event); return }

        if key == NSRightArrowFunctionKey || key == NSLeftArrowFunctionKey {
            let detailsItem = splitViewController.splitViewItems[1]
            if let propertyView = detailsItem.viewController.children.first as? PropertyView {
                propertyView.navigate(direction: Int(key))
            }
        } else {
            super.keyDown(with: event)
        }
    }


}
