//
//  FileImportController.swift
//  Subler
//
//  Created by Damiano Galassi on 09/10/2017.
//

import Cocoa

protocol FileImportControllerDelegate : AnyObject {
    func didSelect(tracks: [MP42Track], metadata: MP42Metadata?)
}

class FileImportController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    private enum ItemType {
        case file(MP42FileImporter)
        case track(Settings)
    }

    private struct Action {
        let title: String
        let tag: Int
        let enabled: Bool
    }
    
    private class Settings {
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
            var actions: [Action] = Array()

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
                
                if (needsConversion) {
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
            default:
                break
            }
            self.actions = actions

            // Set the action menu selection
            // AC-3 Specific actions
            if track.format == kMP42AudioCodecType_AC3 || track.format == kMP42AudioCodecType_EnhancedAC3 &&
                UserDefaults.standard.bool(forKey: "SBAudioConvertAC3"), let audioTrack = track as? MP42AudioTrack {
                if UserDefaults.standard.bool(forKey: "SBAudioKeepAC3") && audioTrack.fallbackTrack == nil {
                    self.selectedActionTag = 6
                } else if audioTrack.fallbackTrack != nil {
                    self.selectedActionTag = 0
                } else {
                    self.selectedActionTag = UInt(UserDefaults.standard.integer(forKey: "SBAudioMixdown"))
                }
            }
            // DTS Specific actions
            else if track.format == kMP42AudioCodecType_DTS &&
                UserDefaults.standard.bool(forKey: "SBAudioConvertDts"), let audioTrack = track as? MP42AudioTrack {
                if audioTrack.fallbackTrack != nil {
                    self.selectedActionTag = 0
                }
                else {
                    switch UserDefaults.standard.integer(forKey: "SBAudioDtsOptions") {
                    case 1: self.selectedActionTag = 7; // Convert to AC-3
                    case 2: self.selectedActionTag = 6; // Keep DTS
                    default: self.selectedActionTag = UInt(UserDefaults.standard.integer(forKey: "SBAudioMixdown"))
                    }
                }
            }
            // Vobsub
            else if track.format == kMP42SubtitleCodecType_VobSub && UserDefaults.standard.bool(forKey: "SBSubtitleConvertBitmap") {
                self.selectedActionTag = 1
            }
            // Generic actions
            else if needsConversion {
                if track is MP42AudioTrack {
                    self.selectedActionTag = UInt(UserDefaults.standard.integer(forKey: "SBAudioMixdown"))
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

    @IBOutlet var tableView: SBTableView!
    @IBOutlet var importMetadataCheckbox: NSButton!

    override public var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "FileImportController")
    }
    
    init(fileURLs: [URL], delegate: FileImportControllerDelegate) throws {
        self.delegate = delegate
        
        var rows: [ItemType] = Array()
        
        let fileImporters: [MP42FileImporter] = fileURLs.flatMap {
            let importer = MP42FileImporter(url: $0, error: nil)
            rows.append(ItemType.file(importer))
            
            let tracks = importer.tracks.map { ItemType.track(Settings(track: $0)) }
            rows.append(contentsOf: tracks)
            return importer
        }

        self.metadata = fileImporters.first?.metadata
        self.items = rows
        self.importMetadata = metadata != nil
        
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.importMetadataCheckbox.isEnabled = importMetadata
    }

    // MARK: Public properties

    private var settings: [Settings] {
        return items.flatMap {
            switch $0 {
            case .file(_):
                return nil
            case .track(let settings):
                return settings
            }
        }
    }

    var onlyContainsSubtitles: Bool {
        return settings.filter { $0.track.format != kMP42SubtitleCodecType_3GText && $0.track as? MP42SubtitleTrack == nil } .isEmpty
    }

    // MARK: Selection

    private func reloadCheckColumn(forRowIndexes indexes: IndexSet) {
        let columnIndex = tableView.column(withIdentifier: checkColumn)
        tableView.reloadData(forRowIndexes: indexes, columnIndexes: IndexSet(integer: columnIndex))
    }

    private func setCheck(value: Bool, forIndexes indexes: IndexSet) {
        for index in indexes {
            let item = items[index]
            switch item {
            case .file(_):
                break
            case .track(let settings):
                settings.checked = value && settings.importable
            }
        }
        reloadCheckColumn(forRowIndexes: indexes)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if let action = menuItem.action,
            action == #selector(self.checkSelected(_:)) ||
            action == #selector(self.uncheckSelected(_:)) ||
            action == #selector(self.checkOnlyTracksWithSameLanguage(_:)) {
            if tableView.selectedRow != -1 || tableView.clickedRow != -1 {
                return true
            }
        }
        return false
    }
    
    @IBAction func checkSelected(_ sender: Any) {
        setCheck(value: true, forIndexes: tableView.targetedRowIndexes)
    }
    
    @IBAction func uncheckSelected(_ sender: Any) {
        setCheck(value: false, forIndexes: tableView.targetedRowIndexes)
    }
    
    @IBAction func checkOnlyTracksWithSameLanguage(_ sender: Any) {
        let languages = tableView.targetedRowIndexes.flatMap {
            let item = items[$0]
            switch item {
            case .file(_):
                return nil
            case .track(let settings):
                return settings.track.language
            }
        }

        for settings in settings {
            settings.checked = settings.importable && languages.contains(settings.track.language)
        }

        reloadCheckColumn(forRowIndexes: IndexSet(integersIn: 0..<items.count))
    }
    
    // MARK: IBActions
    
    @IBAction func closeWindow(_ sender: Any) {
        window?.sheetParent?.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
    }
    
    @IBAction func addTracks(_ sender: Any) {

        var selectedTracks: [MP42Track] = Array()
        let checkedTracks = settings.filter { $0.checked }

        for trackSettings in checkedTracks {
            switch trackSettings.track {
            case let track as MP42AudioTrack:
                
                if trackSettings.selectedActionTag > 0 {
                    let bitRate = UInt(UserDefaults.standard.integer(forKey: "SBAudioBitrate"))
                    let drc = UserDefaults.standard.float(forKey: "SBAudioDRC")
                    let mixdown = Int64(trackSettings.selectedActionTag)

                    let copyTrack = trackSettings.selectedActionTag == 6 || trackSettings.selectedActionTag == 7 ? true : false
                    let convertDTSToAC3 = trackSettings.selectedActionTag == 7 ? true : false

                    if copyTrack {
                        let copy = track.copy() as! MP42AudioTrack
                        let settings = MP42AudioConversionSettings.audioConversion(withBitRate: bitRate, mixDown: kMP42AudioMixdown_DolbyPlII, drc: drc)

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
                        let settings = MP42AudioConversionSettings.audioConversion(withBitRate: bitRate, mixDown: mixdown, drc: drc)
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

        window?.sheetParent?.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
    }
    
    // MARK: Actions

    @IBAction func setImportMetadata(_ sender: NSButton) {
        importMetadata = sender.state == NSControl.StateValue.on
    }

    @IBAction func setCheck(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        if row == -1 { return }

        switch items[row] {
        case .file(_):
            break
        case .track(let settings):
            settings.checked = sender.state.rawValue > 0
        }
    }

    @IBAction func setActionValue(_ sender: NSPopUpButton) {
        let row = tableView.row(for: sender)
        if row == -1 { return }

        switch items[row] {
        case .file(_):
            break
        case .track(let settings):
            settings.selectedActionTag = UInt(sender.indexOfSelectedItem)
        }
    }
    
    // MARK: Table View
    
    let checkColumn = NSUserInterfaceItemIdentifier(rawValue: "check")
    let trackIdColumn = NSUserInterfaceItemIdentifier(rawValue: "trackId")
    let trackNameColumn = NSUserInterfaceItemIdentifier(rawValue: "trackName")
    let trackDurationColumn = NSUserInterfaceItemIdentifier(rawValue: "trackDuration")
    let trackLanguageColumn = NSUserInterfaceItemIdentifier(rawValue: "trackLanguage")
    let trackInfoColumn = NSUserInterfaceItemIdentifier(rawValue: "trackInfo")
    let trackActionColumn = NSUserInterfaceItemIdentifier(rawValue: "trackAction")
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch items[row] {
        case .file(let importer):
            let groupCell = tableView.makeView(withIdentifier: trackNameColumn, owner:self) as? NSTableCellView
            groupCell?.textField?.stringValue = importer.fileURL.lastPathComponent
            return groupCell
            
        case .track(let settings):
            switch tableColumn?.identifier {

            case checkColumn?:
                let cell = tableView.makeView(withIdentifier: checkColumn, owner:self) as? CheckBoxCellView
                cell?.checkboxButton?.state = settings.checked ? NSControl.StateValue.on : NSControl.StateValue.off
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
                    _ = settings.actions.map {
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
}
