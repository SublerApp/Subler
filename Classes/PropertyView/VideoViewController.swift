//
//  VideoViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 22/03/2018.
//

import Cocoa
import MP42Foundation

final class VideoViewController: PropertyView {

    private let file: MP42File
    var track: MP42VideoTrack {
        didSet {
            mediaTagsController.track = track
            reloadUI()
        }
    }

    private let mediaTagsController: MediaTagsController

    override var nibName: NSNib.Name? {
        return "VideoView"
    }

    init(mp4: MP42File, track: MP42VideoTrack) {
        self.file = mp4
        self.track = track
        self.mediaTagsController = MediaTagsController(track: track)

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // UI

    @IBOutlet var mediaTagsView: NSView!

    @IBOutlet var forcedView: NSView!
    @IBOutlet var forcedHeight: NSLayoutConstraint!

    @IBOutlet var profileView: NSView!
    @IBOutlet var profileHeight: NSLayoutConstraint!

    @IBOutlet var colorView: NSView!
    @IBOutlet var colorHeight: NSLayoutConstraint!

    @IBOutlet var colorProfilePopUp: NSPopUpButton!

    @IBOutlet var sampleWidth: NSTextField!
    @IBOutlet var sampleHeight: NSTextField!

    @IBOutlet var trackWidth: NSTextField!
    @IBOutlet var trackHeight: NSTextField!

    @IBOutlet var hSpacing: NSTextField!
    @IBOutlet var vSpacing: NSTextField!

    @IBOutlet var offsetX: NSTextField!
    @IBOutlet var offsetY: NSTextField!

    @IBOutlet var alternateGroup: NSPopUpButton!

    @IBOutlet var videoProfile: NSPopUpButton!

    @IBOutlet var forcedSubs: NSPopUpButton!
    @IBOutlet var forced: NSPopUpButton!

    @IBOutlet var preserveAspectRatio: NSButton!

    @IBOutlet var profileLevelUnchanged: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Media Tags controls
        mediaTagsController.view.frame = mediaTagsView.bounds
        mediaTagsController.view.autoresizingMask = [.width, .height]

        mediaTagsView.addSubview(mediaTagsController.view)

        reloadUI()
    }

    // MARK: H.264

    private func profileName(_ profile: UInt8) -> String {
        switch profile {
        case 66:
            return "Baseline"
        case 77:
            return "Main"
        case 88:
            return "Extended"
        case 100:
            return "High"
        case 110:
            return "High 10"
        case 122:
            return "High 4:2:2"
        case 144:
            return "High 4:4:4"
        default:
            return "Unknown profile"
        }
    }

    private func levelName(_ level: UInt8) -> String {
        switch level {
        case 10, 20, 30, 40, 50:
            return "\(level/10)"
        case 11, 12, 13, 21, 22, 31, 32, 41, 42, 51:
            return "\(level/10).\(level % 10)"
        default:
            return "unknown level \(level)"
        }
    }

    private func colorProfileName(_ colorPrimaries: UInt16, _ transferCharacteristics: UInt16, _ matrixCoefficients: UInt16) -> String {
        let colorTag = (colorPrimaries, transferCharacteristics, matrixCoefficients)
        switch colorTag {
        case (0, 0, 0):
            return NSLocalizedString("Implicit", comment: "Implicit color profile")
        case (1, 1, 1):
            return NSLocalizedString("Rec. 709 (1-1-1)", comment: "color profile")
        case (9, 16, 9):
            return NSLocalizedString("Rec. 2100 PQ (9-16-9)", comment: "color profile")
        case (9, 18, 9):
            return NSLocalizedString("Rec. 2100 HLG (9-18-9)", comment: "color profile")
        case (9, 1, 9):
            return NSLocalizedString("Rec. 2020 (9-1-9)", comment: "color profile")
        case (5, 1, 6):
            return NSLocalizedString("Rec. 601 (5-1-6)", comment: "color profile")
        case (6, 1, 6):
            return NSLocalizedString("Rec. 601 (6-1-6)", comment: "color profile")
        case (11, 17, 6):
            return NSLocalizedString("P3-DCI (11-17-6)", comment: "color profile")
        case (12, 17, 6):
            return NSLocalizedString("P3-D65 (12-17-6)", comment: "color profile")
        case (1, 13, 1):
            return NSLocalizedString("sRGB (1-13-1)", comment: "color profile")
        case (9, 16, 15):
            return NSLocalizedString("IPT-C2 (9-16-15)", comment: "color profile")
        case (2, 2, 2):
            return NSLocalizedString("Undefined (2-2-2)", comment: "color profile")
        default:
            return "\(colorTag.0)-\(colorTag.1)-\(colorTag.2)"
        }
    }

    private func reloadUI() {
        alternateGroup.selectItem(at: Int(track.alternateGroup))

        sampleWidth.stringValue = String(track.width)
        sampleHeight.stringValue = String(track.height)

        trackWidth.stringValue = String(UInt64(track.trackWidth))
        trackHeight.stringValue = String(UInt64(track.trackHeight))

        hSpacing.stringValue = String(track.hSpacing)
        vSpacing.stringValue = String(track.vSpacing)

        offsetX.stringValue = String(Int64(track.transform.tx))
        offsetY.stringValue = String(Int64(track.transform.ty))

        // H.264 Profile and level
        if track.format == kMP42VideoCodecType_H264 && track.origProfile != 0 && track.origLevel != 0 {
            profileView.isHidden = false
            profileHeight.constant = 91

            profileLevelUnchanged.title = "\(NSLocalizedString("Current profile:", comment: "")) \(profileName(track.origProfile)) @ \(levelName(track.origLevel))"

            if track.origProfile == track.newProfile && track.origLevel == track.newLevel {
                videoProfile.selectItem(withTag: 1)
            } else {
                if track.newProfile == 66 && track.newLevel == 21 {
                    videoProfile.selectItem(withTag: 6621)
                } else if track.newProfile == 77 && track.newLevel == 31 {
                    videoProfile.selectItem(withTag: 7731)
                } else if track.newProfile == 100 && track.newLevel == 31 {
                    videoProfile.selectItem(withTag: 10031)
                } else if track.newProfile == 100 && track.newLevel == 41 {
                    videoProfile.selectItem(withTag: 10041)
                }
            }
        } else {
            profileView.isHidden = true
            profileHeight.constant = 0
        }

        // Color tag
        if track.format == kMP42VideoCodecType_H264 || track.format == kMP42VideoCodecType_MPEG4Video ||
            track.format == kMP42VideoCodecType_HEVC || track.format == kMP42VideoCodecType_HEVC_PSinBitstream ||
            track.format == kMP42VideoCodecType_VVC || track.format == kMP42VideoCodecType_VVC_PSinBitstream ||
            track.format == kMP42VideoCodecType_AV1  || track.format == kMP42VideoCodecType_DolbyVisionHEVC {
            colorView.isHidden = false
            colorHeight.constant = 24

            let colorProfile = colorProfileName(track.colorPrimaries, track.transferCharacteristics, track.matrixCoefficients)
            colorProfilePopUp.selectItem(withTitle: colorProfile)

            if colorProfilePopUp.indexOfSelectedItem == -1 {
                colorProfilePopUp.addItem(withTitle: colorProfile)
                colorProfilePopUp.selectItem(withTitle: colorProfile)
            }
        } else {
            colorView.isHidden = true
            colorHeight.constant = 0
        }

        while forced.numberOfItems > 1 {
            forced.removeItem(at: 1)
        }

        // Subtitles forced track
        if let track = track as? MP42SubtitleTrack {
            forcedView.isHidden = false
            forcedHeight.constant = 46

            if track.someSamplesAreForced == false && track.allSamplesAreForced == false {
                forcedSubs.selectItem(withTag: 0)
            } else if track.someSamplesAreForced == true && track.allSamplesAreForced == false {
                forcedSubs.selectItem(withTag: 1)
            } else if track.allSamplesAreForced == true {
                forcedSubs.selectItem(withTag: 2)
            }

            let langs = MP42Languages.defaultManager

            if let subtitlesTracks = file.tracks(withMediaType: kMP42MediaType_Subtitle) as? [MP42SubtitleTrack] {
                for subTrack in subtitlesTracks {
                    let trackID = subTrack.trackId > 0 ? String(subTrack.trackId) : "na"
                    let item = NSMenuItem(title: "\(trackID) - \(subTrack.name) - \(langs.localizedLang(forExtendedTag: subTrack.language))",
                        action: #selector(setForcedTrack(_:)),
                        keyEquivalent: "")
                    item.target = self
                    item.representedObject = subTrack
                    forced.menu?.addItem(item)

                    if track.forcedTrack == subTrack {
                        forced.select(item)
                    }
                }
            }
        } else {
            forcedView.isHidden = true
            forcedHeight.constant = 0
        }
    }

    // MARK: Actions

    private func updateChangeCount() {
        view.window?.windowController?.document?.updateChangeCount(NSDocument.ChangeType.changeDone)
    }

    @IBAction func setSize(_ sender: NSTextField) {
        if sender == trackWidth {
            let value = trackWidth.floatValue
            if track.trackWidth != value {
                if preserveAspectRatio.state == .on {
                    track.trackHeight = track.trackHeight / track.trackWidth * value
                    trackHeight.floatValue = track.trackHeight
                }
                track.trackWidth = value
                updateChangeCount()
            }
        } else if sender == trackHeight {
            let value = trackHeight.floatValue
            if track.trackHeight != value {
                track.trackHeight = value
                updateChangeCount()
            }
        } else if sender == offsetX {
            let value = CGFloat(offsetX.integerValue)
            if track.transform.tx != value {
                var transform = track.transform
                transform.tx = value
                track.transform = transform
                updateChangeCount()
            }
        } else if sender == offsetY {
            let value = CGFloat(offsetY.integerValue)
            if track.transform.ty != value {
                var transform = track.transform
                transform.ty = value
                track.transform = transform
                updateChangeCount()
            }
        }
    }

    @IBAction func setPixelAspect(_ sender: NSTextField) {
        if sender == hSpacing {
            let value = UInt64(hSpacing.integerValue)
            if track.hSpacing != value {
                track.hSpacing = value
                updateChangeCount()
            }
        }
        else if sender == vSpacing {
            let value = UInt64(vSpacing.intValue)
            if track.vSpacing != value {
                track.vSpacing = value
                updateChangeCount()
            }
        }
    }

    @IBAction func setColorProfile(_ sender: NSPopUpButton) {
        var colorTag: (UInt16, UInt16, UInt16) = (0, 0, 0)
        switch sender.selectedTag() {
        case 1:
            colorTag = (0, 0, 0)
        case 2:
            colorTag = (5, 1, 6)
        case 3:
            colorTag = (6, 1, 6)
        case 4:
            colorTag = (1, 1, 1)
        case 5:
            colorTag = (9, 1, 9)
        case 6:
            colorTag = (9, 16, 9)
        case 7:
            colorTag = (9, 18, 9)
        case 8:
            colorTag = (11, 17, 6)
        case 9:
            colorTag = (12, 17, 6)
        case 10:
            colorTag = (1, 13, 1)
        case 11:
            colorTag = (9, 16, 15)
        case 12:
            colorTag = (2, 2, 2)
        default:
            return
        }

        if track.colorPrimaries != colorTag.0 || track.transferCharacteristics != colorTag.1 || track.matrixCoefficients != colorTag.2 {
            track.colorPrimaries = colorTag.0
            track.transferCharacteristics = colorTag.1
            track.matrixCoefficients = colorTag.2
            updateChangeCount()
        }
    }

    @IBAction func setProfileLevel(_ sender: NSPopUpButton) {
        switch sender.selectedTag() {
        case 1:
            track.newProfile = track.origProfile
            track.newLevel = track.origLevel
        case 6621:
            track.newProfile = 66
            track.newLevel = 21
        case 7731:
            track.newProfile = 77
            track.newLevel = 31
        case 10031:
            track.newProfile = 100
            track.newLevel = 31
        case 10041:
            track.newProfile = 100
            track.newLevel = 41
        default:
            return
        }
        updateChangeCount()
    }

    @IBAction func setForcedSubtitles(_ sender: NSPopUpButton) {
        if let track = track as? MP42SubtitleTrack {
            var value: (Bool, Bool) = (false, false)

            switch sender.selectedTag() {
            case 0:
                value = (false, false)
            case 1:
                value = (true, false)
            case 2:
                value = (true, true)
            default:
                break
            }

            if track.someSamplesAreForced != value.0 || track.allSamplesAreForced != value.1 {
                track.someSamplesAreForced = value.0
                track.allSamplesAreForced = value.1
                updateChangeCount()
            }
        }
    }

    @IBAction func setForcedTrack(_ sender: NSMenuItem) {
        if let track = track as? MP42SubtitleTrack {
            if let newForcedTrack = sender.representedObject as? MP42SubtitleTrack {
                if newForcedTrack != track.forcedTrack {
                    track.forcedTrack = newForcedTrack
                    updateChangeCount()
                }
            }
            else {
                track.forcedTrack = nil
                updateChangeCount()
            }
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
