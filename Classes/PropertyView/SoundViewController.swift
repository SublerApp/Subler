//
//  SoundViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 11/11/2017.
//

import Cocoa
import MP42Foundation

final class SoundViewController : PropertyView {

    let file: MP42File
    var track: MP42AudioTrack {
        didSet {
            mediaTagsController.track = track
            reloadUI()
        }
    }

    let mediaTagsController: MediaTagsController

    @IBOutlet var mediaTagsView: NSView!
    @IBOutlet var volume: NSSlider!
    @IBOutlet var alternateGroup: NSPopUpButton!
    @IBOutlet var fallbacksPopUp: NSPopUpButton!
    @IBOutlet var followsPopUp: NSPopUpButton!

    override var nibName: NSNib.Name? {
        return "SoundView"
    }

    init(mp4: MP42File, track: MP42AudioTrack) {
        self.file = mp4
        self.track = track
        self.mediaTagsController = MediaTagsController(track: track)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Media Tags controls
        mediaTagsController.view.frame = mediaTagsView.bounds
        mediaTagsController.view.autoresizingMask = [.width, .height]

        mediaTagsView.addSubview(mediaTagsController.view)

        reloadUI()
    }

    private func reloadUI() {
        // Standard audio controls
        volume.floatValue = track.volume * 100
        alternateGroup.selectItem(at: Int(track.alternateGroup))

        let langs = MP42Languages.defaultManager

        while fallbacksPopUp.numberOfItems > 1 {
            fallbacksPopUp.removeItem(at: 1)
        }

        if (track.format == kMP42AudioCodecType_AC3 || track.format == kMP42AudioCodecType_EnhancedAC3 ||
            track.format == kMP42AudioCodecType_DTS) &&
            track.conversionSettings?.format != kMP42AudioCodecType_MPEG4AAC,
            let audioTracks = file.tracks(withMediaType: kMP42MediaType_Audio) as? [MP42AudioTrack] {

            fallbacksPopUp.isEnabled = true

            for audioTrack in audioTracks where isAAC(track: audioTrack) {
                let trackID = audioTrack.trackId > 0 ? String(audioTrack.trackId) : "na"
                let item = NSMenuItem(title: "\(trackID) - \(audioTrack.name) - \(langs.localizedLang(forExtendedTag: audioTrack.language))",
                                      action: #selector(setTrackFallback(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = audioTrack
                fallbacksPopUp.menu?.addItem(item)

                if track.fallbackTrack == audioTrack {
                    fallbacksPopUp.select(item)
                }
            }
        } else {
            fallbacksPopUp.isEnabled = false
        }

        while followsPopUp.numberOfItems > 1 {
            followsPopUp.removeItem(at: 1)
        }

        if let subtitlesTracks = file.tracks(withMediaType: kMP42MediaType_Subtitle) as? [MP42SubtitleTrack] {
            for subTrack in subtitlesTracks {
                let trackID = subTrack.trackId > 0 ? String(subTrack.trackId) : "na"
                let item = NSMenuItem(title: "\(trackID) - \(subTrack.name) - \(langs.localizedLang(forExtendedTag: subTrack.language))",
                    action: #selector(setTrackFollows(_:)),
                    keyEquivalent: "")
                item.target = self
                item.representedObject = subTrack
                followsPopUp.menu?.addItem(item)

                if track.followsTrack == subTrack {
                    followsPopUp.select(item)
                }
            }
        }
    }

    private func isAAC(track: MP42AudioTrack) -> Bool {
        return track.format == kMP42AudioCodecType_MPEG4AAC ||
            track.format == kMP42AudioCodecType_MPEG4AAC_HE ||
            track.conversionSettings?.format == kMP42AudioCodecType_MPEG4AAC
    }
    
    // MARK: Actions

    private func updateChangeCount() {
        view.window?.windowController?.document?.updateChangeCount(NSDocument.ChangeType.changeDone)
    }

    @IBAction func setTrackVolume(_ sender: NSSlider) {
        let value = sender.floatValue / 100
        if value != track.volume {
            track.volume = value
            updateChangeCount()
        }
    }

    @IBAction func setTrackFallback(_ sender: NSMenuItem) {
        if let newFallbackTrack = sender.representedObject as? MP42AudioTrack {
            if newFallbackTrack != track.fallbackTrack {
                track.fallbackTrack = newFallbackTrack
                updateChangeCount()
            }
        }
        else {
            track.fallbackTrack = nil
            updateChangeCount()
        }
    }

    @IBAction func setTrackFollows(_ sender: NSMenuItem) {
        if let newFollowsTrack = sender.representedObject as? MP42SubtitleTrack {
            if newFollowsTrack != track.followsTrack {
                track.followsTrack = newFollowsTrack
                updateChangeCount()
            }
        }
        else {
            track.followsTrack = nil
            updateChangeCount()
        }
    }

    @IBAction func setTrackAlternateGroup(_ sender: NSPopUpButton) {
        if let group = sender.selectedItem?.tag {
            if track.alternateGroup != group {
                track.alternateGroup = UInt64(group)
                updateChangeCount()
            }
        }
    }
}
