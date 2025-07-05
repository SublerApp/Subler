//
//  FileImportController.swift
//  Subler
//
//  Created by Damiano Galassi on 09/10/2017.
//

import Cocoa
import MP42Foundation

protocol FileImportControllerDelegate : AnyObject {
    func didSelect(tracks: [MP42Track], metadata: MP42Metadata?)
}

final class FileImportController: ViewController, NSTableViewDataSource, NSTableViewDelegate, NSUserInterfaceValidations {

    private enum ItemType {
        case file(MP42FileImporter)
        case track(Settings)
    }

    private struct Action {
        let title: String
        let tag: Int
        let enabled: Bool
    }
    
    private final class Settings {
        let track: MP42Track
        let importable: Bool
        let actions: [Action]
        var selectedActionTag: UInt
        var checked: Bool

        init(track: MP42Track) {
            self.track = track

            let needsConversion = trackNeedConversion(track.format)
            let muxable = isTrackMuxable(track.format)
            self.checked = needsConversion || muxable ? true : false
            self.importable = needsConversion || muxable ? true : false

            // Set up the actions
            var actions: [Action] = []

            switch track {
            case is MP42ClosedCaptionTrack, is MP42ChapterTrack:
                let action = Action(title: NSLocalizedString("Passthru", comment: "File Import action menu item."),
                                    tag: 0,
                                    enabled: true)
                actions.append(action)

            case is MP42SubtitleTrack:
                let action = Action(title: NSLocalizedString("Passthru", comment: "File Import action menu item."),
                                    tag: 0,
                                    enabled: needsConversion == false)
                actions.append(action)
                
                if (needsConversion || track.format == kMP42SubtitleCodecType_VobSub) {
                    let conversionAction = Action(title: NSLocalizedString("Tx3g", comment: "File Import action menu item."),
                                                  tag: 1,
                                                  enabled: true)
                    actions.append(conversionAction)
                }

            case is MP42VideoTrack:
                if track.url?.pathExtension.caseInsensitiveCompare("264") == ComparisonResult.orderedSame ||
                    track.url?.pathExtension.caseInsensitiveCompare("h264") == ComparisonResult.orderedSame  {
                    let formats = ["23.976", "24", "25", "29.97", "30", "50", "59.96", "60"]
                    let tags = [2398, 24, 25, 2997, 30, 50, 5994, 60]
                    
                    for frameRate in zip(formats, tags) {
                        let action = Action(title: frameRate.0,
                                            tag: frameRate.1,
                                            enabled: true)
                        actions.append(action)
                    }
                }
                else {
                    let action = Action(title: NSLocalizedString("Passthru", comment: "File Import action menu item."),
                                        tag: 0,
                                        enabled: muxable == true)
                    actions.append(action)
                }

            case is MP42AudioTrack:
                
                let action = Action(title: NSLocalizedString("Passthru", comment: "File Import action menu item."),
                                    tag: 0,
                                    enabled: needsConversion == false)
                actions.append(action)

                let formats = ["AAC - Dolby Pro Logic II", "AAC - Dolby Pro Logic", "AAC - Stereo", "AAC - Mono", "AAC - Multi-channel"]
                let tags = [kMP42AudioMixdown_DolbyPlII, kMP42AudioMixdown_Dolby, kMP42AudioMixdown_Stereo, kMP42AudioMixdown_Mono, kMP42AudioMixdown_None]

                for mixdown in zip(formats, tags) {
                    let conversionAction = Action(title: mixdown.0,
                                                  tag: Int(mixdown.1),
                                                  enabled: true)
                    actions.append(conversionAction)
                }
                
                if track.format == kMP42AudioCodecType_AC3 ||
                    track.format == kMP42AudioCodecType_EnhancedAC3 ||
                    track.format == kMP42AudioCodecType_DTS {
                    let conversionAction = Action(title: NSLocalizedString("AAC + Passthru", comment: "File Import action menu item."),
                                                  tag: 6,
                                                  enabled: true)
                    actions.append(conversionAction)
                }
                
                if track.format == kMP42AudioCodecType_DTS {
                    let conversionAction = Action(title: NSLocalizedString("AAC + AC3", comment: "File Import action menu item."),
                                                  tag: 7,
                                                  enabled: true)
                    actions.append(conversionAction)
                }

                let audioTrack = track as! MP42AudioTrack
                let channelCount = audioTrack.channels
                
                if track.format == kMP42AudioCodecType_MPEG4AAC && channelCount > 2 {
                    let conversionAction = Action(title: NSLocalizedString("AAC + Passthru", comment: "File Import action menu item."),
                                                tag: 6,
                                                enabled: true)
                    actions.append(conversionAction)
                }
                
            default:
                break
            }
            self.actions = actions

            // Set the action menu selection
            // AC-3 Specific actions
            if (track.format == kMP42AudioCodecType_AC3 || track.format == kMP42AudioCodecType_EnhancedAC3) &&
                Prefs.audioConvertAC3, let audioTrack = track as? MP42AudioTrack {
                if Prefs.audioKeepAC3 && audioTrack.fallbackTrack == nil {
                    self.selectedActionTag = 6
                } else if audioTrack.fallbackTrack != nil {
                    self.selectedActionTag = 0
                } else {
                    self.selectedActionTag = Prefs.audioMixdown
                }
            }
            // DTS Specific actions
            else if track.format == kMP42AudioCodecType_DTS &&
                Prefs.audioConvertDts, let audioTrack = track as? MP42AudioTrack {
                if audioTrack.fallbackTrack != nil {
                    self.selectedActionTag = 0
                }
                else {
                    switch Prefs.audioDtsOptions {
                    case 1: self.selectedActionTag = 7; // Convert to AC-3
                    case 2: self.selectedActionTag = 6; // Keep DTS
                    default: self.selectedActionTag = Prefs.audioMixdown
                    }
                }
            }
            // Vobsub
            else if track.format == kMP42SubtitleCodecType_VobSub && Prefs.subtitleConvertBitmap {
                self.selectedActionTag = 1
            }
            // Generic actions
            else if needsConversion {
                if track is MP42AudioTrack {
                    self.selectedActionTag = Prefs.audioMixdown
                } else {
                    self.selectedActionTag = 1
                }
            }
            else {
                self.selectedActionTag = 0
            }
        }
    }

    private let metadata: MP42Metadata?
    private let items: [ItemType]

    private var importMetadata: Bool
    private weak var delegate: FileImportControllerDelegate?

    @IBOutlet var tracksTableView: ExpandedTableView!
    @IBOutlet var importMetadataCheckbox: NSButton!

    override public var nibName: NSNib.Name? {
        return "FileImportController"
    }
    
    init(fileURLs: [URL], delegate: FileImportControllerDelegate) throws {
        let importers = try fileURLs.map { try MP42FileImporter(url: $0) }
        self.items = importers.flatMap { [ItemType.file($0)] + $0.tracks.map { ItemType.track(Settings(track: $0)) } }
        self.metadata = importers.first?.metadata
        self.importMetadata = metadata != nil && MetadataPrefs.keepImportedFilesMetadata
        self.delegate = delegate

        super.init(nibName: nil, bundle: nil)

        self.autosave = "FileImportControllerAutosaveIdentifier"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.importMetadataCheckbox.isEnabled = metadata != nil
        self.importMetadataCheckbox.state = MetadataPrefs.keepImportedFilesMetadata ? .on : .off
    }

    private var settings: [Settings] {
        return items.compactMap {
            switch $0 {
            case .file(_):
                return nil
            case .track(let settings):
                return settings
            }
        }
    }

    // MARK: Public properties

    private var containsTracks: Bool {
        settings.isEmpty == false
    }

    var onlyContainsSubtitles: Bool {
        containsTracks && settings.allSatisfy { $0.track.format == kMP42SubtitleCodecType_3GText || $0.track as? MP42SubtitleTrack != nil }
    }

    var onlyContainsMetadata: Bool {
        containsTracks == false && metadata != nil
    }

    // MARK: Selection

    private func reloadCheckColumn(forRowIndexes indexes: IndexSet) {
        let columnIndex = tracksTableView.column(withIdentifier: checkColumn)
        tracksTableView.reloadData(forRowIndexes: indexes, columnIndexes: IndexSet(integer: columnIndex))
    }

    private func setCheck(value: Bool, forIndexes indexes: IndexSet) {
        var modifiedIndexes = IndexSet()
        for index in indexes {
            let item = items[index]
            switch item {
            case .file(_):
                break
            case .track(let settings):
                settings.checked = value && settings.importable
                modifiedIndexes.insert(index)
            }
        }
        reloadCheckColumn(forRowIndexes: modifiedIndexes)
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let action = item.action,
            action == #selector(self.checkSelected(_:)) ||
            action == #selector(self.uncheckSelected(_:)) ||
            action == #selector(self.checkOnlyTracksWithSameLanguage(_:)) ||
			action == #selector(self.checkOnlySelectedTracks(_:)) {
            if tracksTableView.selectedRow != -1 || tracksTableView.clickedRow != -1 {
                return true
            }
        }
        return false
    }
    
    @IBAction func checkSelected(_ sender: Any) {
        setCheck(value: true, forIndexes: tracksTableView.targetedRowIndexes)
    }
    
    @IBAction func uncheckSelected(_ sender: Any) {
        setCheck(value: false, forIndexes: tracksTableView.targetedRowIndexes)
    }
    
    @IBAction func checkOnlyTracksWithSameLanguage(_ sender: Any) {
        let languages = tracksTableView.targetedRowIndexes.compactMap { (index: Int) -> String? in
            let item = items[index]
            switch item {
            case .file(_):
                return nil
            case .track(let settings):
                return settings.track.language
            }
        }

        var modifiedIndexes = IndexSet()

        items.enumerated().forEach { (index, item) in
            switch item {
            case .file(_):
                break
            case .track(let settings):
                settings.checked = settings.importable && languages.contains(settings.track.language)
                modifiedIndexes.insert(index)
            }
        }

        reloadCheckColumn(forRowIndexes: modifiedIndexes)
    }
	
	@IBAction func checkOnlySelectedTracks(_ sender: Any) {
		let targetedIndices = tracksTableView.targetedRowIndexes;
        var modifiedIndexes = IndexSet()

        items.enumerated().forEach { (index, item) in
            switch item {
            case .file(_):
                break
            case .track(let settings):
                settings.checked = targetedIndices.contains(index)
                modifiedIndexes.insert(index)
            }
        }

        reloadCheckColumn(forRowIndexes: modifiedIndexes)
    }
    
    // MARK: IBActions
    
    @IBAction func closeWindow(_ sender: Any) {
        presentingViewController?.dismiss(self)
    }
    
    @IBAction func addTracks(_ sender: Any) {
        logTracksTable()
        
        var selectedTracks: [MP42Track] = []

        for trackSettings in settings where trackSettings.checked {
            switch trackSettings.track {
            case let track as MP42AudioTrack:
                
                if trackSettings.selectedActionTag > 0 {
                    let bitRate = Prefs.audioBitrate
                    let drc = Prefs.audioDRC
                    let mixdown = Int64(trackSettings.selectedActionTag)

                    let copyTrack = trackSettings.selectedActionTag == 6 || trackSettings.selectedActionTag == 7 ? true : false
                    let convertDTSToAC3 = trackSettings.selectedActionTag == 7 ? true : false

                    if copyTrack {
                        let copy = track.copy() as! MP42AudioTrack
                        let copyMixdown = MP42AudioMixdown(Prefs.audioMixdown)
                        let settings = MP42AudioConversionSettings.audioConversion(withBitRate: bitRate, mixDown: copyMixdown, drc: drc)

                        copy.conversionSettings = settings

                        track.fallbackTrack = copy
                        track.isEnabled = false

                        if convertDTSToAC3 {
                            // Wouldn't it be better to use pref settings too instead of 640/Multichannel and the drc from the prefs?
                            track.conversionSettings = MP42AudioConversionSettings(format: kMP42AudioCodecType_AC3, bitRate: 640, mixDown: kMP42AudioMixdown_None, drc: drc)
                        }

                        selectedTracks.append(copy)
                    }
                    else {
                        let settings = MP42AudioConversionSettings.audioConversion(withBitRate: bitRate, mixDown: MP42AudioMixdown(mixdown), drc: drc)
                        track.conversionSettings = settings;
                    }
                }
                selectedTracks.append(trackSettings.track)

            case let track as MP42SubtitleTrack:

                if trackSettings.selectedActionTag > 0 {
                    track.conversionSettings = MP42ConversionSettings.subtitlesConversion()
                }
                selectedTracks.append(trackSettings.track)

            case let track as MP42VideoTrack:

                if track.url?.pathExtension.caseInsensitiveCompare("264") == ComparisonResult.orderedSame ||
                    track.url?.pathExtension.caseInsensitiveCompare("h264") == ComparisonResult.orderedSame  {

                    track.conversionSettings = MP42RawConversionSettings.rawConversion(withFrameRate: trackSettings.selectedActionTag)
                }
                selectedTracks.append(trackSettings.track)

            default:
                selectedTracks.append(trackSettings.track)
            }
        }

        delegate?.didSelect(tracks: selectedTracks,
                            metadata: importMetadata ? metadata : nil)

        presentingViewController?.dismiss(self)
    }
    
    // MARK: Actions

    @IBAction func setImportMetadata(_ sender: NSButton) {
        let enabled = sender.state == .on
        importMetadata = enabled
        MetadataPrefs.keepImportedFilesMetadata = enabled
    }

    @IBAction func setCheck(_ sender: NSButton) {
        let row = tracksTableView.row(for: sender)
        guard row != -1 else { return }

        switch items[row] {
        case .file(_):
            break
        case .track(let settings):
            settings.checked = sender.state.rawValue > 0
        }
    }

    @IBAction func setActionValue(_ sender: NSPopUpButton) {
        let row = tracksTableView.row(for: sender)
        guard let selectedItem = sender.selectedItem, row > -1 else { return }

        switch items[row] {
        case .file(_):
            break
        case .track(let settings):
            settings.selectedActionTag = UInt(selectedItem.tag)
        }
    }

    // MARK: Table View

    private let checkColumn = NSUserInterfaceItemIdentifier(rawValue: "check")
    private let trackIdColumn = NSUserInterfaceItemIdentifier(rawValue: "trackId")
    private let trackNameColumn = NSUserInterfaceItemIdentifier(rawValue: "trackName")
    private let trackDurationColumn = NSUserInterfaceItemIdentifier(rawValue: "trackDuration")
    private let trackLanguageColumn = NSUserInterfaceItemIdentifier(rawValue: "trackLanguage")
    private let trackInfoColumn = NSUserInterfaceItemIdentifier(rawValue: "trackInfo")
    private let trackActionColumn = NSUserInterfaceItemIdentifier(rawValue: "trackAction")

    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch items[row] {
        case .file(let importer):
            let groupCell = tableView.makeView(withIdentifier: trackNameColumn, owner:self) as? NSTableCellView
            groupCell?.textField?.attributedStringValue = importer.fileURL.lastPathComponent.groupAttributedString()
            return groupCell

        case .track(let settings):
            switch tableColumn?.identifier {

            case checkColumn?:
                let cell = tableView.makeView(withIdentifier: checkColumn, owner:self) as? CheckBoxCellView
                cell?.checkboxButton?.state = settings.checked ? .on : .off
                return cell

            case trackIdColumn?:
                let cell = tableView.makeView(withIdentifier: trackIdColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = String(settings.track.trackId)
                return cell

            case trackNameColumn?:
                let cell = tableView.makeView(withIdentifier: trackNameColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = settings.track.name
                return cell

            case trackDurationColumn?:
                let cell = tableView.makeView(withIdentifier: trackDurationColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = StringFromTime(Int64(settings.track.duration), 1000)
                cell?.textField?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                return cell

            case trackLanguageColumn?:
                let cell = tableView.makeView(withIdentifier: trackLanguageColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = MP42Languages.defaultManager.localizedLang(forExtendedTag: settings.track.language)
                return cell

            case trackInfoColumn?:
                let cell = tableView.makeView(withIdentifier: trackInfoColumn, owner:self) as? NSTableCellView
                cell?.textField?.stringValue = settings.track.formatSummary
                return cell

            case trackActionColumn?:
                let cell = tableView.makeView(withIdentifier: trackActionColumn, owner:self) as? PopUpCellView
                if let menu = cell?.popUpButton?.menu {
                    menu.removeAllItems()
                    settings.actions.forEach {
                        let menuItem = NSMenuItem(title: $0.title, action: nil, keyEquivalent: "")
                        menuItem.tag = $0.tag
                        menuItem.isEnabled = $0.enabled
                        menu.addItem(menuItem)
                    }

                    cell?.popUpButton?.isEnabled = settings.importable
                    cell?.popUpButton?.autoenablesItems = false
                    cell?.popUpButton?.selectItem(withTag: Int(settings.selectedActionTag))
                }
                return cell

            default:
                return nil
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        switch items[row] {
        case .file:
            return true
        default:
            return false
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch items[row] {
        case .file:
            return 19
        default:
            return 18
        }
    }

    // MARK: Private methods

    private func logTracksTable() {
        let logger = Logger.shared

        // Helper function to truncate strings
        func truncate(_ str: String, to length: Int) -> String {
            if str.count <= length {
                return str.padding(toLength: length, withPad: " ", startingAt: 0)
            }
            return String(str.prefix(length - 1)) + "~"
        }

        // Helper function to format duration
        func formatDuration(_ duration: Double, timescale: UInt32) -> String {
            if duration <= 0 || timescale == 0 {
                return "Unknown"
            }
            let seconds = duration / Double(timescale)
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            let secs = Int(seconds) % 60
            let millisecs = Int((seconds - Double(Int(seconds))) * 1000)
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millisecs)
        }

        // Build the entire table as a single string
        var tableLines: [String] = []

        tableLines.append("File Import: Processing tracks with applied settings:")
        tableLines.append("----------------------------------------------------------------------------------------------")
        tableLines.append("|   | Id | Name                  | Duration     | Language      | Info        | Action       |")
        tableLines.append("----------------------------------------------------------------------------------------------")

        var trackId = 1
        for item in items {
            switch item {
            case .file(_):
                // Skip file headers in table format
                break

            case .track(let settings):
                let track = settings.track

                // Get the selected action description
                let selectedAction = settings.actions.first { $0.tag == settings.selectedActionTag }
                let action = selectedAction?.title ?? "Unknown"

                // Format the data with proper truncation and alignment
                let name = truncate(track.name.isEmpty ? "Unnamed" : track.name, to: 21)
                let language = truncate(MP42Languages.defaultManager.localizedLang(forExtendedTag: track.language), to: 13)
                let infoTruncated = truncate(track.formatSummary, to: 10)
                let actionTruncated = truncate(action, to: 13)
                let duration = formatDuration(Double(track.duration), timescale: track.timescale)
                let selected = settings.checked ? "X" : " "
                let id = String(format: "%02d", trackId)

                // Create properly aligned row with fixed column widths
                // The truncate function now handles padding, so we just need to pad duration
                let durationPadded = duration.padding(toLength: 12, withPad: " ", startingAt: 0)

                let row = "| \(selected) | \(id) | \(name) | \(durationPadded) | \(language) | \(infoTruncated) | \(actionTruncated) |"
                tableLines.append(row)

                trackId += 1
            }
        }

        tableLines.append("----------------------------------------------------------------------------------------------")

        // Log the entire table as a single entry
        logger.write(toLog: tableLines.joined(separator: "\n"))
    }
}
