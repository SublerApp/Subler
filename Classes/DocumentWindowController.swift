//
//  DocumentWindowController.swift
//  Subler
//
//  Created by Damiano Galassi on 03/02/2018.
//

import Cocoa

private extension NSPasteboard.PasteboardType {

    static let backwardsCompatibleFileURL: NSPasteboard.PasteboardType = {
        if #available(OSX 10.13, *) {
            return NSPasteboard.PasteboardType.fileURL
        } else {
            return NSPasteboard.PasteboardType(kUTTypeFileURL as String)
        }
    } ()

}

class DocumentWindowController: NSWindowController, TracksViewControllerDelegate, ChapterSearchControllerDelegate, MetadataSearchControllerDelegate, FileImportControllerDelegate, ProgressViewControllerDelegate, NSDraggingDestination {

    private var doc: Document {
        return document as! Document
    }

    private var mp4: MP42File {
        return doc.mp4
    }

    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "DocumentWindowController")
    }

    init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window = window else {
            fatalError("`window` is expected to be non nil by this time.")
        }

        sendToQueue.image = NSImage(named: NSImage.Name(rawValue: "NSShareTemplate"));

        window.contentViewController = splitViewController
        window.registerForDraggedTypes([NSPasteboard.PasteboardType.backwardsCompatibleFileURL])

        if UserDefaults.standard.bool(forKey: "rememberWindowSize") {
            window.setFrameAutosaveName(NSWindow.FrameAutosaveName(rawValue: "documentSave"))
            window.setFrameFrom("documentSave")
        }
        else {
            window.setContentSize(NSSize(width: 690, height: 510))
        }

        if #available(OSX 10.11, *) {} else {
            splitViewController.splitView.setPosition(160, ofDividerAt: 0)
        }

        didSelect(tracks: [])
    }

    private static let splitViewResorationIdentifier = NSUserInterfaceItemIdentifier(rawValue: "splitViewSave")
    private static let splitViewResorationAutosaveName = NSSplitView.AutosaveName(rawValue: "splitViewSave")

    private lazy var splitViewController: NSSplitViewController = {
        // Create a split view controller to contain split view items.
        let splitViewController = NSSplitViewController()
        splitViewController.view.wantsLayer = true
        splitViewController.splitView.isVertical = false
        splitViewController.splitView.dividerStyle = NSSplitView.DividerStyle.thick

        let tracksSplitViewItem = NSSplitViewItem(viewController: tracksViewController)
        if #available(OSX 10.11, *) {
            tracksSplitViewItem.minimumThickness = 100
        }

        splitViewController.addSplitViewItem(tracksSplitViewItem)

        let detailsSplitViewItem = NSSplitViewItem(viewController: DetailsViewController())
        detailsSplitViewItem.canCollapse = true
        if #available(OSX 10.11, *) {
            detailsSplitViewItem.minimumThickness = 320
        }

        splitViewController.addSplitViewItem(detailsSplitViewItem)

        splitViewController.splitView.autosaveName = DocumentWindowController.splitViewResorationAutosaveName
        splitViewController.splitView.identifier = DocumentWindowController.splitViewResorationIdentifier

        return splitViewController
    }()

    private lazy var tracksViewController: TracksViewController = {
        let tracksViewController = TracksViewController(document: doc, delegate: self)
        return tracksViewController
    }()

    private var metadataViewController: SBMovieViewController?
    private var videoViewController: VideoViewController?
    private var soundViewController: SoundViewController?
    private var chapterViewController: ChapterViewController?
    private var multiViewController: MultiSelectViewController?

    private func clearDetailsViewControllers() {
        metadataViewController = nil
        videoViewController = nil
        soundViewController = nil
        chapterViewController = nil
        multiViewController = nil
    }

    private func detailsViewController(_ tracks: [MP42Track]) -> NSViewController {
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

            default:
                if metadataViewController == nil {
                    metadataViewController = SBMovieViewController(nibName: NSNib.Name(rawValue: "MovieView"),
                                                                       bundle: nil)
                    metadataViewController!.metadata = mp4.metadata
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
        if let detailsViewController = detailsItem.viewController.childViewControllers.first {
            doc.undoManager?.removeAllActions(withTarget: detailsViewController)
            detailsViewController.view.removeFromSuperviewWithoutNeedingDisplay()
            detailsItem.viewController.removeChildViewController(at: 0)
        }

        let trackViewController = detailsViewController(tracks)
        detailsItem.viewController.addChildViewController(trackViewController)
        trackViewController.view.frame = detailsItem.viewController.view.bounds
        trackViewController.view.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        detailsItem.viewController.view.addSubview(trackViewController.view)
    }

    // MARK: Validation

    @IBOutlet var addTracks: NSToolbarItem!
    @IBOutlet var deleteTrack: NSToolbarItem!
    @IBOutlet var searchMetadata: NSToolbarItem!
    @IBOutlet var searchChapters: NSToolbarItem!
    @IBOutlet var sendToQueue: NSToolbarItem!

    override func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        if item == addTracks ||
            item == searchMetadata ||
            item == searchChapters ||
            item == sendToQueue {
            return true;
        }

        if item == deleteTrack {
            return tracksViewController.selectedTracks.isEmpty == false && NSApp.isActive;
        }

        return false
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(selectFile(_:)),
             #selector(selectMetadataFile(_:)),
             #selector(searchMetadata(_:)),
             #selector(searchChapters(_:)),
             #selector(addChaptersEvery(_:)),
             #selector(iTunesFriendlyTrackGroups(_:)),
             #selector(clearTrackNames(_:)),
             #selector(fixAudioFallbacks(_:)):
            return true

        case #selector(sendToExternalApp(_:)) where mp4.hasFileRepresentation && doc.isDocumentEdited == false:
            return true

        case #selector(showTrackOffsetSheet(_:)) where tracksViewController.selectedTracks.isEmpty == false:
            return true

        case #selector(export(_:)) where tracksViewController.selectedTracks.isEmpty == false:
            if let track = tracksViewController.selectedTracks.first, track.isMuxed {
                return true
            } else {
                return false
            }

        default:
            return false
        }
    }

    // MARK: Save status

    private var progressController: ProgressViewController?

    func startProgressReporting() {
        let progressController = ProgressViewController()
        progressController.delegate = self
        contentViewController?.presentViewControllerAsSheet(progressController)
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
            contentViewController?.dismissViewController(progressController)
            self.progressController = nil
        }
    }

    func cancel() {
        mp4.cancel()
    }

    // MARK: Actions

    private var sheetController: NSWindowController?

    @IBAction func sendToExternalApp(_ sender: Any) {
        let workspace = NSWorkspace.shared
        if let filePath = doc.fileURL?.path, let appPath = workspace.fullPath(forApplication: "iTunes") {
            workspace.openFile(filePath, withApplication: appPath)
        }
    }

    @IBAction func deleteTrack(_ sender: Any) {
        let tracks = tracksViewController.selectedTracks
        if tracks.isEmpty == false {
            mp4.removeTracks(tracks)

            if UserDefaults.standard.bool(forKey: "SBOrganizeAlternateGroups") { mp4.organizeAlternateGroups() }
            if UserDefaults.standard.bool(forKey: "SBInferMediaCharacteristics") { mp4.inferMediaCharacteristics() }

            doc.updateChangeCount(.changeDone)
            tracksViewController.reloadData()
        }
    }

    @IBAction func addChaptersEvery(_ sender: NSMenuItem) {
        let track: MP42ChapterTrack = mp4.chapters ?? { let track = MP42ChapterTrack(); self.mp4.addTrack(track); return track }()
        let minutes = sender.tag * 60 * 1000

        if minutes > 0 {
            for (index, duration) in stride(from: 0, to: mp4.duration, by: minutes).enumerated() {
                track.addChapter("Chapter \(index + 1)", duration: UInt64(duration))
            }
        }
        else {
            track.addChapter("Chapter 1", duration: UInt64(mp4.duration))
        }

        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
    }

    @IBAction func iTunesFriendlyTrackGroups(_ sender: Any) {
        mp4.organizeAlternateGroups()
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

    @IBAction func fixAudioFallbacks(_ sender: Any) {
        mp4.setAutoFallback()
        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
    }

    @IBAction func showTrackOffsetSheet(_ sender: Any) {
        guard let track = tracksViewController.selectedTracks.first else { return }
        let controller = OffsetViewController(doc: doc, track: track)
        self.window?.contentViewController?.presentViewControllerAsSheet(controller)
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
        let controller = MetadataSearchController(delegate: self, searchTerms: terms)

        guard let windowForSheet = doc.windowForSheet, let window = controller.window
            else { return }

        sheetController = controller;
        windowForSheet.beginSheet(window, completionHandler: { response in
            self.sheetController = nil
        })
    }

    @IBAction func searchChapters(_ sender: Any?) {
        let name = mp4.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyName).first?.stringValue
        let url = mp4.firstSourceURL() ?? doc.fileURL
        let title = (name?.isEmpty == false ? name : url?.lastPathComponent) ?? ""
        let duration = UInt64(mp4.duration)

        let controller = ChapterSearchController(delegate: self, title: title, duration: duration)

        guard let windowForSheet = doc.windowForSheet, let window = controller.window
            else { return }

        sheetController = controller;
        windowForSheet.beginSheet(window, completionHandler: { response in
            self.sheetController = nil
        })
    }

    func didSelect(metadata: MetadataResult) {
        let defaults = UserDefaults.standard
        let map = metadata.mediaKind == .movie ? defaults.map(forKey: "SBMetadataMovieResultMap2") : defaults.map(forKey: "SBMetadataTvShowResultMap2")
        let keepEmptyKeys = defaults.bool(forKey: "SBMetadataKeepEmptyAnnotations")

        if let map = map {
            let result = metadata.mappedMetadata(to: map, keepEmptyKeys: keepEmptyKeys)
            mp4.metadata.merge(result)
        }

        if let hdType = mp4.hdType {
            for item in mp4.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyHDVideo) {
                mp4.metadata.removeItem(item)
            }
            mp4.metadata.addItem(MP42MetadataItem(identifier: MP42MetadataKeyHDVideo, value: NSNumber(value: hdType.rawValue),
                                                  dataType: .integer, extendedLanguageTag: nil))
        }
        doc.updateChangeCount(.changeDone)
        metadataViewController?.reloadData()
    }

    func didSelect(chapters: [MP42TextSample]) {
        let chapterTrack = MP42ChapterTrack()
        for chapter in chapters {
            chapterTrack.addChapter(chapter)
        }

        mp4.addTrack(chapterTrack)
        doc.updateChangeCount(.changeDone)
        tracksViewController.reloadData()
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
        if ext == "xml" || ext == "nfo" {
            let metadata = MP42Metadata(url: fileURL)
            mp4.metadata.merge(metadata)

            doc.updateChangeCount(.changeDone)
            metadataViewController?.reloadData()
        }
        else if let file = try? MP42File(url: fileURL) {
            mp4.metadata.merge(file.metadata)

            doc.updateChangeCount(.changeDone)
            metadataViewController?.reloadData()
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
                self.sheetController = nil;
            }
            else {
                guard let windowForSheet = doc.windowForSheet, let window = controller.window
                    else { return }

                sheetController = controller;
                windowForSheet.beginSheet(window, completionHandler: { response in
                    self.sheetController = nil
                })
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

    func didSelect(tracks: [MP42Track], metadata: MP42Metadata?) {
        for track in tracks {
            mp4.addTrack(track)
        }

        if tracks.isEmpty == false {
            doc.updateChangeCount(.changeDone)

            if UserDefaults.standard.bool(forKey: "SBOrganizeAlternateGroups") {
                mp4.organizeAlternateGroups()
                if UserDefaults.standard.bool(forKey: "SBInferMediaCharacteristics") {
                    mp4.inferMediaCharacteristics()
                }
            }
        }

        if let metadata = metadata {
            mp4.metadata.merge(metadata)
            doc.updateChangeCount(.changeDone)
            metadataViewController?.reloadData()
        }

        tracksViewController.reloadData()
    }

    // MARK: Drag & drop

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard().types,
            types.contains(NSPasteboard.PasteboardType.backwardsCompatibleFileURL) &&
                sender.draggingSourceOperationMask().contains(.copy)
        else { return [] }

        return .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard()
        guard let types = pasteboard.types,
            types.contains(NSPasteboard.PasteboardType.backwardsCompatibleFileURL),
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

}
