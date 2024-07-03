//
//  MediaTagsController.swift
//  Subler
//
//  Created by Damiano Galassi on 22/03/2018.
//

import Cocoa
import MP42Foundation

///  A MediaTag is composed of a tag value and a boolean state.
private class MediaTag {

    /// Returns the complete array of the predefined tags.
    static let predefinedTags: [String] = ["public.main-program-content", "public.auxiliary-content", "public.original-content",
                                           "public.subtitles.forced-only", "public.accessibility.transcribes-spoken-dialog",
                                           "public.accessibility.describes-music-and-sound", "public.accessibility.enhances-speech-intelligibility",
                                           "public.easy-to-read", "public.accessibility.describes-video", "public.translation.dubbed",
                                           "public.translation.voice-over", "public.translation"]

    /// Returns the predefined supported media tags
    /// for a particular media type.
    ///
    /// - Parameter mediaType: a MP42MediaType type.
    /// - Returns: an array of String with the supported tags.
    static func predefinedTags(for mediaType: MP42MediaType) -> [String] {
        var tags = ["public.main-program-content", "public.auxiliary-content", "public.original-content"]

        if mediaType == kMP42MediaType_Audio {
            tags += ["public.accessibility.describes-video", "public.accessibility.enhances-speech-intelligibility", "public.translation.dubbed", "public.translation.voice-over"]
        }
        if mediaType == kMP42MediaType_Subtitle ||
            mediaType == kMP42MediaType_ClosedCaption {
            tags += ["public.subtitles.forced-only", "public.accessibility.transcribes-spoken-dialog",
                      "public.accessibility.describes-music-and-sound", "public.easy-to-read"]
        }
        if mediaType == kMP42MediaType_Subtitle ||
            mediaType == kMP42MediaType_ClosedCaption ||
            mediaType == kMP42MediaType_Audio {
            tags += ["public.translation"]
        }

        return tags
    }

    /// Returns the localized human readable title of a partical tag
    /// - Parameter tag: tag value
    /// - Returns: localized title if available
    static func localizedTitle(for tag: String) -> String? {
        let localizedDescriptions = ["public.main-program-content": NSLocalizedString("Main Program Content", comment: "Media characteristic."),
                                     "public.auxiliary-content": NSLocalizedString("Auxiliary Content", comment: "Media characteristic."),
                                     "public.original-content": NSLocalizedString("Original Content", comment: "Media characteristic."),
                                     "public.subtitles.forced-only": NSLocalizedString("Contains Only Forced Subtitles", comment: "Media characteristic."),
                                     "public.accessibility.transcribes-spoken-dialog": NSLocalizedString("Transcribes Spoken Dialog For Accessibility", comment: "Media characteristic."),
                                     "public.accessibility.describes-music-and-sound": NSLocalizedString("Describes Music And Sound For Accessibility", comment: "Media characteristic."),
                                     "public.accessibility.enhances-speech-intelligibility": NSLocalizedString("Enhances speech intelligibility", comment: "Media characteristic."),
                                     "public.easy-to-read": NSLocalizedString("Easy To Read", comment: "Media characteristic."),
                                     "public.accessibility.describes-video": NSLocalizedString("Describes Video For Accessibility", comment: "Media characteristic."),
                                     "public.translation.dubbed": NSLocalizedString("Dubbed Translation", comment: "Media characteristic."),
                                     "public.translation.voice-over": NSLocalizedString("Voice Over Translation", comment: "Media characteristic."),
                                     "public.translation": NSLocalizedString("Language Translation", comment: "Media characteristic.")]
        return localizedDescriptions[tag]
    }

    var state: Bool
    let value: String
    let localizedTitle: String

    init(value: String, state: Bool) {
        self.state = state
        self.value = value
        self.localizedTitle = MediaTag.localizedTitle(for: value) ?? value
    }
}

/// A NSTableCellView that contains a single checkbox.
class CheckBoxTableCellView: NSTableCellView {
    @IBOutlet var checkBox: NSButton!
    fileprivate var representedTag: MediaTag? {
        didSet {
            checkBox.title = representedTag?.localizedTitle ?? "Unknown"
            checkBox.state = representedTag?.state == true ? .on : .off
        }
    }
}

/// A MediaTagsController takes a MP42Track in input,
/// and show a windows to configure the media characteristic tags
/// of the input track. The new set of tags is added to the track
/// after the user press the OK button.
///
/// Custom media tags are preserved.
final class MediaTagsController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet var tableView: NSTableView!

    var track: MP42Track {
        didSet {
            reloadUI()
        }
    }
    private var tags: [MediaTag]

    override var nibName: NSNib.Name? {
        return "MediaTagsController"
    }

    /// Initializes an SBMediaTagsController with the tags
    ///  from the provided track.
    ///
    /// - Parameter track: the track
    init(track: MP42Track) {
        self.track = track
        self.tags = []
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        tableView.delegate = nil
        tableView.dataSource = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadUI()
    }

    private func reloadUI() {
        let predefinedValues = MediaTag.predefinedTags(for: track.mediaType)
        var tags: [MediaTag] = []

        // Add the predefined tags
        for value in predefinedValues {
            let state = track.mediaCharacteristicTags.contains(value) ? true : false
            let tag = MediaTag(value: value, state: state)
            tags.append(tag)
        }

        // Keep the custom ones if present
        let customValues = Set(track.mediaCharacteristicTags).filter { predefinedValues.contains($0) == false }

        for value in customValues {
            let tag = MediaTag(value: value, state: true)
            tags.append(tag)
        }

        self.tags = tags

        tableView.reloadData()
    }

    // MARK: Table view data source

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tags.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SBCheckBoxTableCellView"), owner: self) as? CheckBoxTableCellView
        view?.representedTag = tags[row]
        return view
    }

    // MARK: Table view actions

    @IBAction func setTagState(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        tags[row].state = sender.state == .on ? true : false
        updateTrack()
    }

    private func updateTrack() {
        let updatedTags = tags.filter { $0.state }.map { $0.value }
        track.mediaCharacteristicTags = Set(updatedTags)

        view.window?.windowController?.document?.updateChangeCount(.changeDone)
    }
}
