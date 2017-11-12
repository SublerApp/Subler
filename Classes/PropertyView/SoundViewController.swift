//
//  SoundViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 11/11/2017.
//

import Cocoa

class SoundViewController : NSViewController {

    var track: MP42AudioTrack {
        didSet {
        }
    }

    let fallbacks: [MP42AudioTrack]
    let follows: [MP42SubtitleTrack]
    let mediaTagsController: SBMediaTagsController

    @IBOutlet var mediaTagsView: NSView!
    @IBOutlet var volume: NSSlider!
    @IBOutlet var alternateGroup: NSPopUpButton!
    @IBOutlet var fallback: NSPopUpButton!
    @IBOutlet var follow: NSPopUpButton!

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "SoundView")
    }

    init(mp4: MP42File, track: MP42AudioTrack) {
        self.track = track
        self.fallbacks = Array()
        self.follows = Array()
        self.mediaTagsController = SBMediaTagsController(track: track)

        super.init(nibName: self.nibName, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        // Media Tags controls
        mediaTagsController.view.frame = mediaTagsView.bounds
        mediaTagsController.view.autoresizingMask = [.width, .height]

        mediaTagsView.addSubview(mediaTagsController.view)

        // Standard audio controls
        alternateGroup.selectItem(at: Int(track.alternateGroup))

        

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

    @IBAction func seTracktFallback(_ sender: NSPopUpButton) {
        let index = sender.tag

        if index > -1 {
            let newFallbackTrack = fallbacks[index]
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

    @IBAction func setTrackFollows(_ sender: NSPopUpButton) {
        let index = sender.tag

        if index > -1 {
            let newFollowskTrack = follows[index]
            if newFollowskTrack != track.followsTrack {
                track.followsTrack = newFollowskTrack
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
