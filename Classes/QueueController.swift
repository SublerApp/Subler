//
//  QueueController.swift
//  Subler
//
//  Created by Damiano Galassi on 26/01/2019.
//

import Cocoa
import MP42Foundation

final class QueueController : NSWindowController, NSWindowDelegate, NSPopoverDelegate, ItemViewDelegate, NSTableViewDataSource, NSTableViewDelegate, ExpandedTableViewDelegate, NSUserInterfaceValidations {

    static let shared = QueueController()

    private let queue: Queue
    private let prefs = QueuePreferences()
    private var popover: NSPopover?
    private var itemPopover: NSPopover?
    private var windowController: OptionsViewController?
    private let toolbarDelegate = QueueToolbarDelegate()

    private let tablePasteboardType = NSPasteboard.PasteboardType("SublerQueueTableViewDataType")
    private lazy var docImg: NSImage = {
        // Load a generic movie icon to display in the table view
        let img = NSWorkspace.shared.icon(forFileType: "mov")
        img.size = NSSize(width: 16, height: 16)
        return img
    }()

    @IBOutlet var table: ExpandedTableView!
    @IBOutlet var statusLabel: NSTextField!
    @IBOutlet var progressBar: NSProgressIndicator!

    override var windowNibName: NSNib.Name? {
        return "Queue"
    }

    private init() {
        popover = nil
        itemPopover = nil
        windowController = nil
        if let url = prefs.queueURL {
            queue = Queue(url: url)
        } else {
            fatalError("Invalid queue url")
        }
        super.init(window: nil)
        _ = window
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        window?.tabbingMode = .disallowed

        if #available(macOS 11, *) {
            window?.toolbarStyle = .unified
        }

        toolbarDelegate.target = self

        let toolbar = NSToolbar(identifier: "SublerQueueToolbar")
        toolbar.delegate = toolbarDelegate
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        if #available(macOS 26, *) {
            toolbar.displayMode = .iconAndLabel
        } else {
            toolbar.displayMode = .iconOnly
        }
        self.window?.toolbar = toolbar

        table.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, tablePasteboardType])
        progressBar.isHidden = true

        let main = OperationQueue.main
        let nc = NotificationCenter.default

        nc.addObserver(forName: Queue.Working, object: queue, queue: main) {(note) in
            guard let info = note.userInfo,
                let status = info["ProgressString"] as? String,
                let progress = info["Progress"] as? Double,
                let index = info["ItemIndex"] as? Int
                else { return }

            self.statusLabel.stringValue = status
            self.progressBar.isIndeterminate = false
            self.progressBar.doubleValue = progress

            if index != NSNotFound {
                self.updateUI(indexes: IndexSet(integer: index))
            }
        }

        nc.addObserver(forName: Queue.Completed, object: queue, queue: main) { (note) in
            self.progressBar.isHidden = true
            self.progressBar.stopAnimation(self)
            self.progressBar.doubleValue = 0
            self.progressBar.isIndeterminate = true

            if let toolbar = self.window?.toolbar {
                self.toolbarDelegate.setState(working: false, toolbar: toolbar)
            }
            self.statusLabel.stringValue = NSLocalizedString("Done", comment: "Queue -> Done")

            self.updateUI()

            if self.prefs.showDoneNotification, let info = note.userInfo {
                let notification = NSUserNotification()
                notification.title = NSLocalizedString("Queue Done", comment: "")

                if let failedCount = info["FailedCount"] as? UInt, failedCount > 0,
                    let completedCount = info["CompletedCount"] as? UInt {
                    notification.informativeText = "Completed: \(completedCount); Failed: \(failedCount)"
                }
                else if let completedCount = info["CompletedCount"] as? UInt {
                    notification.informativeText = "Completed: \(completedCount)"
                }
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
            }

            for script in self.scripts {
                script.resumeExecution(withResult: "Completed")
            }
            self.scripts.removeAll()
        }

        nc.addObserver(forName: Queue.Failed, object: queue, queue: main) { (note) in
            guard let info = note.userInfo,
                let error = info["Error"] as? Error else { return }
            self.presentError(error)
        }

        // Update the UI the first time
        updateUI()
        removeCompletedItems(self)
    }

    //MARK: User Interface Validation

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(removeSelectedItems(_:)):
            if let row = table?.selectedRow, row != -1 {
                let item = queue.item(at: row)
                if item.status != .working {
                    return true
                }
            } else if let row = table?.clickedRow, row != -1 {
                let item = queue.item(at: row)
                if item.status != .working {
                    return true
                }
            }
            return false
        case #selector(showInFinder(_:)):
            if let row = table?.clickedRow, row != -1 {
                let item = queue.item(at: row)
                if item.status == .completed {
                    return true
                }
            }
            return false
        case #selector(edit(_:)):
            if let row = table?.clickedRow, row != -1 {
                let item = queue.item(at: row)
                if item.status == .completed || item.status == .ready {
                    return true
                }
            }
            return false
        case #selector(removeCompletedItems(_:)):
            return true
        case #selector(toggleOptions(_:)):
            return true
        case #selector(toggleStartStop(_:)):
            return true
        case #selector(open(_:)):
            return true
        default:
            return false
        }
    }

    //MARK: Queue

    func saveToDisk() throws {
        prefs.saveUserDefaults()
        try queue.saveToDisk()
    }

    internal func edit(item: QueueItem) {
        let originalStatus = item.status
        item.status = .working

        updateUI(indexes: IndexSet(integer: queue.index(of: item)))

        DispatchQueue.global().async {
            if originalStatus != .completed {
                do {
                    try item.prepare()
                } catch {
                    DispatchQueue.main.async {
                        self.presentError(error)
                    }
                }
            }

            DispatchQueue.main.async {
                do {
                    var doc: Document?
                    if originalStatus == .completed {
                        try doc = Document(contentsOf: item.destURL, ofType: "")
                    } else if let mp4 = item.mp4File {
                        doc = Document(mp4: mp4)
                    }

                    if let doc = doc {
                        NSDocumentController.shared.addDocument(doc)
                        doc.makeWindowControllers()
                        doc.showWindows()

                        self.itemPopover?.close()

                        item.status = originalStatus
                        let index = self.queue.index(of: item)
                        self.remove(at: index)
                        self.updateState()
                    }
                } catch {
                    self.presentError(error)
                }
            }
        }
    }

    //MARK: Items creation

    private func destination(for url: URL) -> URL {
        let value = try? url.resourceValues(forKeys: [URLResourceKey.typeIdentifierKey])

        if let destination = prefs.destination {
            return destination.appendingPathComponent(url.lastPathComponent).deletingPathExtension().appendingPathExtension(prefs.fileType)
        } else if let type = value?.typeIdentifier, UTTypeConformsTo(type as CFString, "public.mpeg-4" as CFString) {
            return url
        } else {
            return url.deletingPathExtension().appendingPathExtension(prefs.fileType)
        }
    }

    /// Creates a new QueueItem from an NSURL,
    /// and adds the current actions to it.
    private func createItem(url: URL) -> QueueItem {

        let destURL = destination(for: url)
        let item = QueueItem(fileURL: url, destination: destURL)

        if prefs.clearExistingMetadata {
            item.addAction(QueueClearExistingMetadataAction())
        }
        if prefs.searchMetadata {
            item.addAction(QueueMetadataAction(movieLanguage: prefs.movieProviderLanguage,tvShowLanguage: prefs.tvShowProviderLanguage, movieProvider: prefs.movieProvider, tvShowProvider: prefs.tvShowProvider, preferredArtwork: prefs.providerArtwork, preferredArtworkSize: prefs.providerArtworkSize))
        }
        if prefs.setOutputFilename {
            item.addAction(QueueSetOutputFilenameAction())
        }
        if prefs.subtitles {
            item.addAction(QueueSubtitlesAction())
        }
        if prefs.organize {
            item.addAction(QueueOrganizeGroupsAction())
        }
        if prefs.fixFallbacks {
            item.addAction(QueueFixFallbacksAction())
        }
        if prefs.clearTrackName {
            item.addAction(QueueClearTrackNameAction())
        }
        if prefs.prettifyAudioTrackName {
            item.addAction(QueuePrettifyAudioTrackNameAction())
        }
        if prefs.renameChapters {
            item.addAction(QueueRenameChaptersAction())
        }
        if prefs.fixTrackLanguage {
            item.addAction(QueueSetLanguageAction(language: prefs.fixTrackLanguageValue))
        }
        if prefs.applyColorSpace, let tag = QueueColorSpaceActionTag(rawValue: UInt16(prefs.applyColorSpaceValue)) {
            item.addAction(QueueColorSpaceAction(tag: tag))
        }
        if let set = prefs.metadataSet {
            item.addAction(QueueSetAction(preset: set))
        }
        if prefs.optimize {
            item.addAction(QueueOptimizeAction())
        }
        if prefs.sendToiTunes {
            item.addAction(QueueSendToiTunesAction())
        }
 //MARK: Change Selected Tracks by Language
        if prefs.changeAudioLanguage {
            item.addAction(QueueChangeAudioLanguageAction(language: prefs.changeAudioLanguageValue))
        }
        if prefs.changeSubtitleLanguage {
            item.addAction(QueueChangeSubtitleLanguageAction(language: prefs.changeSubtitleLanguageValue))
        }
        return item
    }

    //MARK: Queue management

    private var scripts: [NSScriptCommand] = []

    func add(script: NSScriptCommand) {
        scripts.append(script)
    }

    var status: Queue.Status {
        get {
            return queue.status
        }
    }

    var count: Int {
        get {
            return queue.count
        }
    }

    func items(at indexes: IndexSet) -> [QueueItem] {
        return queue.items(at: indexes)
    }

    /// Adds a QueueItem to the queue
    func add(_ item: QueueItem) {
        insert(items: [item], at: IndexSet(integer: IndexSet.Element(queue.count)))
    }

    func add(_ item: QueueItem, applyPreset: Bool) {
        //WHY APPLY PRESET?
        if prefs.optimize {
            item.addAction(QueueOptimizeAction())
        }
        add(item)
    }

    private func add(_ items: [QueueItem], at index: Int) {
        let indexes = IndexSet(integersIn: index ..< (index + items.count))
        insert(items: items, at: indexes)
    }

    /// Adds an array of QueueItem to the queue.
    /// Implements the undo manager.
    func insert(items: [QueueItem], at indexes: IndexSet) {
        if items.isEmpty { return }
        guard let firstIndex = indexes.first else { fatalError() }

        table.beginUpdates()

        // Forward
        var currentIndex = firstIndex
        var currentObjectIndex = 0

        while currentIndex != NSNotFound {
            queue.insert(items[currentObjectIndex], at: currentIndex)
            currentIndex = indexes.integerGreaterThan(currentIndex) ?? NSNotFound
            currentObjectIndex += 1
        }

        table.insertRows(at: indexes, withAnimation: .slideDown)
        table.endUpdates()
        updateState()

        guard let undo = window?.undoManager else { return }

        undo.registerUndo(withTarget: self) { (target) in
            self.remove(at: indexes)
        }

        if undo.isUndoing == false {
            undo.setActionName(NSLocalizedString("Add Queue Item", comment: "Queue -> redo add item."))
        }

        if !(undo.isUndoing || undo.isRedoing) {
            if prefs.autoStart {
                start(self)
            }
        }
    }

    private func remove(at index: Int) {
        remove(at: IndexSet(integer: IndexSet.Element(index)))
    }

    func remove(at indexes: IndexSet) {
        if indexes.isEmpty {
            return
        }

        table.beginUpdates()

        let removedItems = queue.items(at: indexes)

        if queue.count > indexes.last! {
            queue.remove(at: indexes)
        }

        table.removeRows(at: indexes, withAnimation: .slideUp)
        table.selectRowIndexes(IndexSet(integer: indexes.first!), byExtendingSelection: false)

        table.endUpdates()
        updateState()

        guard let undo = window?.undoManager else { return }

        undo.registerUndo(withTarget: self) { (target) in
            self.insert(items: removedItems, at: indexes)
        }

        if undo.isUndoing == false {
            undo.setActionName(NSLocalizedString("Remove Queue Item", comment: "Queue -> redo add item."))
        }
    }

    private func move(items: [QueueItem], at index: Int) {
        var currentIndex = index
        var source: [Int] = []
        var dest: [Int] = []

        table.beginUpdates()

        for item in items.reversed() {
            let sourceIndex = queue.index(of: item)
            queue.remove(at: IndexSet(integer: sourceIndex))

            if sourceIndex < currentIndex {
                currentIndex -= 1
            }

            queue.insert(item, at: currentIndex)

            source.append(currentIndex)
            dest.append(sourceIndex)

            table.moveRow(at: sourceIndex, to: currentIndex)
        }

        table.endUpdates()

        guard let undo = window?.undoManager else { return }

        undo.registerUndo(withTarget: self) { (target) in
            self.move(at: source, to: dest)
        }

        if undo.isUndoing == false {
            undo.setActionName(NSLocalizedString("Move Queue Item", comment: "Queue -> move add item."))
        }
    }

    private func move(at source: [Int], to dest: [Int]) {
        var newSource: [Int] = []
        var newDest: [Int] = []

        table.beginUpdates()

        for (sourceIndex, destIndex) in zip(source, dest).reversed() {
            newSource.append(destIndex)
            newDest.append(sourceIndex)

            if let item = queue.items(at: IndexSet(integer: sourceIndex)).first {
                queue.remove(at: IndexSet(integer: sourceIndex))
                queue.insert(item, at: destIndex)

                table.moveRow(at: sourceIndex, to: destIndex)
            }
        }

        table.endUpdates()

        guard let undo = window?.undoManager else { return }

        undo.registerUndo(withTarget: self) { (target) in
            self.move(at: newSource, to: newDest)
        }

        if undo.isUndoing == false {
            undo.setActionName(NSLocalizedString("Move Queue Item", comment: "Queue -> move add item."))
        }
    }

    private func items(contentOf url: URL) -> [QueueItem] {
        var items: [QueueItem] = []
        let supportedFileFormats = MP42FileImporter.supportedFileFormats()

        let value = try? url.resourceValues(forKeys: [URLResourceKey.isDirectoryKey])

        if let isDirectory = value?.isDirectory, isDirectory == true,
            let directoryEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles], errorHandler: nil) {

            for fileURL in directoryEnumerator {

                let fileValue = try? url.resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
                if fileValue?.isDirectory ?? false {
                    if let fileURL = fileURL as? URL, supportedFileFormats.contains(fileURL.pathExtension.lowercased()) {
                        items.append(createItem(url: fileURL))
                    }
                }
            }
            items.sort { return $0.fileURL.lastPathComponent.localizedStandardCompare($1.fileURL.lastPathComponent) == ComparisonResult.orderedAscending }
        } else if supportedFileFormats.contains(url.pathExtension.lowercased()) {
            items.append(createItem(url: url))
        }

        return items
    }

    func insert(contentOf urls: [URL], at index: Int) {
        let sorted = urls.sorted(by: { return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == ComparisonResult.orderedAscending })
        let result = sorted.flatMap { items(contentOf: $0) }
        add(result, at: index)
    }

    //MARK: Popover delegate

    /// Creates a popover with the queue options.
    private func createOptionsPopover() {
        if popover == nil {
            let p = NSPopover()
            p.contentViewController = OptionsViewController(options: prefs)
            p.animates = true
            p.behavior = NSPopover.Behavior.semitransient
            p.delegate = self

            popover = p
        }
    }

    /// Creates a popover with a QueueItem
    private func createItemPopover(_ item: QueueItem) {
        let p = NSPopover()

        let view = ItemViewController(item: item, delegate: self)
        p.contentViewController = view
        p.animates = true
        p.behavior = NSPopover.Behavior.semitransient
        p.delegate = self

        itemPopover = p
    }

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return popover == self.popover
    }

    func popoverDidClose(_ notification: Notification) {
        guard let closedPopover = notification.object as? NSPopover
            else { return }

        if popover == closedPopover {
            popover = nil
        }
        if itemPopover == closedPopover {
            itemPopover = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        windowController = nil
    }

    //MARK: UI

    /// Updates the count on the app dock icon.
    private func updateDockTile() {
        let count = queue.readyCount + ((queue.status == .working) ? 1 : 0)

        if count > 0 {
            NSApp.dockTile.badgeLabel = "\(count)"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
    }

    private func updateUI(indexes: IndexSet) {
        table.reloadData(forRowIndexes: indexes, columnIndexes: IndexSet(integer: 0))
        updateState()
    }

    private func updateUI() {
        table.reloadData()
        updateState()
    }

    private func updateState() {
        if queue.status != .working {
            if queue.count == 1 {
                statusLabel.stringValue = NSLocalizedString("1 item in queue", comment: "")
            } else {
                statusLabel.stringValue = String.localizedStringWithFormat(NSLocalizedString("%lu items in queue.", comment: ""), queue.count)
            }
        }
        updateDockTile()
    }

    @IBAction func start(_ sender: Any?) {
        if queue.status == .working {
            return
        }

        if let toolbar = self.window?.toolbar {
            self.toolbarDelegate.setState(working: true, toolbar: toolbar)
        }
        statusLabel.stringValue = NSLocalizedString("Working.", comment: "Queue -> Working")
        progressBar.isHidden = false
        progressBar.startAnimation(self)

        window?.undoManager?.removeAllActions(withTarget: self)

        queue.start()
    }

    @IBAction func stop(_ sender: Any?) {
        queue.stop()
    }

    @IBAction func toggleStartStop(_ sender: Any?) {
        if queue.status == .working {
            stop(self)
        } else {
            start(self)
        }
    }

    @IBAction func toggleOptions(_ sender: Any?) {
        guard let window = self.window else { return }
        createOptionsPopover()

        if let p = popover, p.isShown == false {
            let toolbarItem = window.toolbar?.visibleItems?.first(where: { $0.itemIdentifier == .queueSettings })
            let target = ((toolbarItem?.view?.window) != nil) ? toolbarItem?.view : window.contentView

            if #available(macOS 14, *) {
                if let toolbarItem, let toolbar = window.toolbar, toolbar.isVisible == true {
                    p.show(relativeTo: toolbarItem)
                } else if let target {
                    p.show(relativeTo: target.bounds, of: target, preferredEdge: .maxY)
                }
            } else if let target {
                p.show(relativeTo: target.bounds, of: target, preferredEdge: .maxY)
            }
        } else {
            popover?.close()
            popover = nil
        }
    }

    @IBAction func toggleItemsOptions(_ sender: Any?) {
        guard let sender = sender as? NSView else { return }
        let index = table.row(for: sender)
        let item = queue.item(at: index)

        if let p = itemPopover, p.isShown, let controller = p.contentViewController as? ItemViewController, controller.item == item {
            p.close()
            itemPopover = nil
        } else {
            createItemPopover(item)
            itemPopover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxX)
        }
    }

    //MARK: Open

    @IBAction func open(_ sender: Any?) {
        guard let windowForSheet = window else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedFileTypes = MP42FileImporter.supportedFileFormats()

        panel.beginSheetModal(for: windowForSheet) { (response) in
            if response == NSApplication.ModalResponse.OK {
                self.insert(contentOf: panel.urls, at: self.queue.count)
            }
        }
    }

    //MARK: Table View

    func numberOfRows(in tableView: NSTableView) -> Int {
        return queue.count
    }

    private let nameColumn = NSUserInterfaceItemIdentifier(rawValue: "nameColumn")

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn?.identifier == nameColumn {
            let item = queue.item(at: row)
            let cell = tableView.makeView(withIdentifier: nameColumn, owner: self) as? NSTableCellView
            cell?.textField?.stringValue = item.fileURL.lastPathComponent

            switch item.status {
            case .editing:
                cell?.imageView?.image = NSImage(named: "EncodeWorking")
            case .working:
                cell?.imageView?.image = NSImage(named: "EncodeWorking")
            case .completed:
                cell?.imageView?.image = NSImage(named: "EncodeComplete")
            case .failed:
                cell?.imageView?.image = NSImage(named: "EncodeCanceled")
            case .cancelled:
                cell?.imageView?.image = NSImage(named: "EncodeCanceled")
            case .ready:
                cell?.imageView?.image = docImg
            }
            return cell
        }
        return nil
    }

    func deleteSelection(in tableView: NSTableView) {
        var rowIndexes = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow

        if clickedRow != -1 && rowIndexes.contains(clickedRow) == false {
            rowIndexes.removeAll()
            rowIndexes.insert(clickedRow)
        }

        let items = queue.items(at: rowIndexes)

        for item in items where item.status == .working {
            rowIndexes.remove(IndexSet.Element(queue.index(of: item)))
        }

        if rowIndexes.isEmpty == false {
            remove(at: rowIndexes)
        }
    }

    @IBAction func edit(_ sender: Any?) {
        let clickedRow = table.clickedRow
        if clickedRow > -1 {
            let item = queue.item(at: clickedRow)
            edit(item: item)
        }
    }

    @IBAction func showInFinder(_ sender: Any?) {
        let clickedRow = table.clickedRow
        if clickedRow > -1 {
            let item = queue.item(at: clickedRow)
            NSWorkspace.shared.activateFileViewerSelecting([item.destURL])
        }
    }

    @IBAction func removeSelectedItems(_ sender: Any?) {
        deleteSelection(in: table)
    }

    @IBAction func removeCompletedItems(_ sender: Any?) {
        remove(at: queue.indexesOfItems(with: .completed))
    }

    //MARK: Drag & Drop

    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: true)
        pboard.declareTypes([tablePasteboardType], owner: self)
        pboard.setData(data, forType: tablePasteboardType)
        return true
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if info.draggingSource == nil {
            tableView.setDropRow(row, dropOperation: .above)
            return .copy
        } else if let source = info.draggingSource as? NSTableView, tableView == source && dropOperation == .above {
            return .every
        } else {
            return []
        }
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let pboard = info.draggingPasteboard

        if let source = info.draggingSource as? NSTableView, source == tableView, let rowData = pboard.data(forType: tablePasteboardType), let rowIndexes = NSKeyedUnarchiver.unarchiveObject(with: rowData) as? IndexSet {

            let items = queue.items(at: rowIndexes)
            move(items: items, at: row)
            return true

        } else {

            if pboard.types?.contains(NSPasteboard.PasteboardType.fileURL) ?? false {
                if let items = pboard.readObjects(forClasses: [NSURL.classForCoder()], options: [:]) as? [URL] {
                    insert(contentOf: items, at: row)
                }
                return true
            }
        }

        return false
    }
}
