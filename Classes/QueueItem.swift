//
//  QueueItem.swift
//  Subler
//
//  Created by Damiano Galassi on 28/01/2019.
//

import Foundation
import MP42Foundation

class QueueItem: NSObject, NSSecureCoding {

    @objc enum Status: Int {
        case ready
        case editing
        case working
        case completed
        case failed
        case cancelled
    }

    @objc dynamic let fileURL: URL
    @objc dynamic var destURL: URL

    var mp4File: MP42File?
    var localizedWorkingDescription: String?

    weak var delegate: Queue?

    private var statusInternal: Status
    private let uniqueID: String
    private var attributes: [String : Any]
    private var actionsInternal: [QueueActionProtocol]

    private var cancelled: Bool
    private let queue: DispatchQueue

    private init(fileURL: URL, destURL: URL) {
        statusInternal = .ready
        uniqueID = UUID().uuidString
        actionsInternal = []
        attributes = [:]
        cancelled = false
        self.fileURL = fileURL
        self.destURL = destURL
        queue = DispatchQueue(label: "org.subler.itemQueue")
    }

    convenience init(fileURL: URL, destination: URL) {
        self.init(fileURL: fileURL, destURL: destination)

        var url = fileURL
        url.removeCachedResourceValue(forKey: URLResourceKey.fileSizeKey)
        let value = try? url.resourceValues(forKeys: [URLResourceKey.fileSizeKey])

        if let fileSize = value?.fileSize, fileSize > 3800000000 {
            attributes[MP4264BitData] = true
        }

        if UserDefaults.standard.bool(forKey: "chaptersPreviewTrack") {
            attributes[MP42GenerateChaptersPreviewTrack] = true
            attributes[MP42ChaptersPreviewPosition] = UserDefaults.standard.float(forKey: "SBChaptersPreviewPosition")
        }
    }

    convenience init(mp4: MP42File) {
        self.init(fileURL: mp4.url!, destURL: mp4.url!)
        mp4File = mp4

        if UserDefaults.standard.bool(forKey: "chaptersPreviewTrack") {
            attributes[MP42GenerateChaptersPreviewTrack] = true
            attributes[MP42ChaptersPreviewPosition] = UserDefaults.standard.float(forKey: "SBChaptersPreviewPosition")
        }
    }

    convenience init(mp4: MP42File, destURL: URL, attributes: [String : Any] = [:], optimize: Bool = false) {
        self.init(fileURL: destURL, destURL: destURL)
        self.mp4File = mp4
        self.attributes = attributes

        if optimize {
            addAction(QueueOptimizeAction())
        }
    }

    // MARK: Public properties

    @objc dynamic var status: Status {
        get {
            var status: Status = .ready
            queue.sync {
                status = statusInternal
            }
            return status
        }
        set (newStatus) {
            queue.sync {
                statusInternal = newStatus
            }
        }
    }

    // MARK: Actions

    @objc dynamic var actions: [QueueActionProtocol] {
        get {
            var result: [QueueActionProtocol] = []
            queue.sync {
                result = actionsInternal
            }
            return result
        }
    }

    func addAction(_ action: QueueActionProtocol) {
        willChangeValue(for: \.actions)
        queue.sync {
            actionsInternal.append(action)
        }
        didChangeValue(for: \.actions)
    }

    func removeAction(at index: Int) {
        willChangeValue(for: \.actions)
        _ = queue.sync {
            actionsInternal.remove(at: index)
        }
        didChangeValue(for: \.actions)
    }

    // MARK: Item processing

    enum ProcessError: Error {
        case fileExists
        case fileNotFound
        case outOfDiskSpace
        case optimizationFailure
    }

    private func checkDiskSpace(at url: URL) -> Int {
        var directoryURL = url
        directoryURL.removeCachedResourceValue(forKey: .volumeAvailableCapacityKey)
        let value = try? directoryURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        if let availableCapacity = value?.volumeAvailableCapacity {
            return availableCapacity
        } else {
            return 0
        }
    }

    private func configureAudio(track: MP42AudioTrack, mp4: MP42File) {
        var conversionNeeded = false

        let ud = UserDefaults.standard
        let bitrate = ud.integer(forKey: "SBAudioBitrate")
        let drc = ud.float(forKey: "SBAudioDRC")
        let mixdown = Int64(ud.integer(forKey: "SBAudioMixdown"))

        // AC-3 track, we might need to do the aac + ac3 trick.
        if track.format == kMP42AudioCodecType_AC3 ||
            track.format == kMP42AudioCodecType_EnhancedAC3 {

            if ud.bool(forKey: "SBAudioConvertAC3") {
                if ud.bool(forKey: "SBAudioKeepAC3") && track.fallbackTrack == nil {
                    let copy = track.copy() as! MP42AudioTrack
                    let settings = MP42AudioConversionSettings(format: kMP42AudioCodecType_MPEG4AAC, bitRate: UInt(bitrate), mixDown: mixdown, drc: drc)
                    copy.conversionSettings = settings

                    track.fallbackTrack = copy
                    track.isEnabled = false

                    mp4.addTrack(copy)
                } else {
                    conversionNeeded = true
                }
            }
        }
        // DTS -> convert only if specified in the prefs.
        else if track.format ==  kMP42AudioCodecType_DTS {
            if ud.bool(forKey: "SBAudioConvertDts") {
                switch ud.integer(forKey: "SBAudioDtsOptions") {
                case 1: // Convert to AC-3

                    let copy = track.copy() as! MP42AudioTrack
                    let settings = MP42AudioConversionSettings(format: kMP42AudioCodecType_MPEG4AAC, bitRate: UInt(bitrate), mixDown: mixdown, drc: drc)
                    copy.conversionSettings = settings

                    track.fallbackTrack = copy
                    track.isEnabled = false

                    // Wouldn't it be better to use pref settings too instead of 640/Multichannel and the drc from the prefs?
                    track.conversionSettings = MP42AudioConversionSettings(format: kMP42AudioCodecType_AC3, bitRate: 640, mixDown: kMP42AudioMixdown_None, drc: drc)

                    mp4.addTrack(copy)

                case 2: // Keep DTS

                    let copy = track.copy() as! MP42AudioTrack
                    let settings = MP42AudioConversionSettings(format: kMP42AudioCodecType_MPEG4AAC, bitRate: UInt(bitrate), mixDown: mixdown, drc: drc)
                    copy.conversionSettings = settings

                    track.fallbackTrack = copy
                    track.isEnabled = false

                    mp4.addTrack(copy)

                default:
                    conversionNeeded = true
                }
            }
        }

        // If an audio track needs to be converted, apply the mixdown from the preferences.
        if trackNeedConversion(track.format) || conversionNeeded {
            let settings = MP42AudioConversionSettings(format: kMP42AudioCodecType_MPEG4AAC, bitRate: UInt(bitrate), mixDown: mixdown, drc: drc)
            track.conversionSettings = settings
        }
    }

    private func configureSubtitles(track: MP42SubtitleTrack, mp4: MP42File) {
        // VobSub -> only if specified in the prefs.
        if track.format == kMP42SubtitleCodecType_VobSub && UserDefaults.standard.bool(forKey: "SBSubtitleConvertBitmap") {
            let settings = MP42ConversionSettings.subtitlesConversion()
            track.conversionSettings = settings
        } else if trackNeedConversion(track.format) {
            let settings = MP42ConversionSettings.subtitlesConversion()
            track.conversionSettings = settings
        }
    }

    func prepare() throws {

        defer {
            localizedWorkingDescription = nil
            delegate?.updateProgress(0)
        }

        if FileManager.default.fileExists(atPath: fileURL.path) == false {
            throw ProcessError.fileNotFound
        }

        if mp4File == nil {
            let value = try? fileURL.resourceValues(forKeys: [URLResourceKey.typeIdentifierKey])

            if let type = value?.typeIdentifier, type == "com.apple.m4a-audio" || type == "com.apple.m4v-video" || type == "public.mpeg-4" {
                mp4File = try MP42File(url: fileURL)
            } else {
                let mp4 = MP42File()
                let importer = try MP42FileImporter(url: fileURL)
                let activeTracks = importer.tracks.filter { isTrackMuxable($0.format) || trackNeedConversion($0.format) }

                mp4.metadata.merge(importer.metadata)

                for track in activeTracks {

                    if let track = track as? MP42AudioTrack {
                        configureAudio(track: track, mp4: mp4)
                    } else if let track = track as? MP42SubtitleTrack {
                        configureSubtitles(track: track, mp4: mp4)
                    }

                    mp4.addTrack(track)
                }
                mp4File = mp4
            }
        }

        for action in actions.filter({ $0.type == .pre }) {
            localizedWorkingDescription = action.localizedDescription
            delegate?.updateProgress(0)
            _ = action.runAction(self)
        }
    }

    func process() throws {

        guard let filePathURL = (fileURL as NSURL?)?.filePathURL else { return }

        #if SB_SANDBOX
            destURL?.startAccessingSecurityScopedResource()
        #endif

        defer {
            mp4File?.progressHandler = nil
            mp4File = nil

            #if SB_SANDBOX
            destURL?.stopAccessingSecurityScopedResource()
            #endif
        }

        // The file has been added directly to the queue
        if mp4File == nil {
            try prepare()
        }

        guard let mp4 = mp4File else { return }

        mp4.progressHandler = { [weak self] in self?.delegate?.updateProgress($0) }

        // Check if there is enough space on the destination disk
        if filePathURL != destURL {
            let availableCapacity = checkDiskSpace(at: destURL.deletingLastPathComponent())
            if mp4.dataSize > availableCapacity {
                throw ProcessError.outOfDiskSpace
            }
        }

        if cancelled == false {
            if filePathURL == destURL && mp4.hasFileRepresentation {
                // We have an existing mp4 file, update it
                try mp4.update(options: attributes)
            } else {
                // Write the new file to disk
                try mp4.write(to: destURL, options: attributes)
            }
        }

        if cancelled == false {
            for action in actions.filter( { $0.type == .post }) {
                localizedWorkingDescription = action.localizedDescription
                delegate?.updateProgress(0)
                let result = action.runAction(self)
                if result == false, let _ = action as? QueueOptimizeAction {
                    throw ProcessError.optimizationFailure
                }
            }
            localizedWorkingDescription = nil
        }
    }

    func cancel() {
        queue.sync {
            self.cancelled = true
            mp4File?.cancel()
        }
    }

    // MARK: AppleScript

    @objc func name() -> String {
        return destURL.lastPathComponent
    }

    @objc func sourcePath() -> String {
        return fileURL.path
    }

    @objc func destinationPath() -> String {
        return destURL.path
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        get {
            let appDescription = NSApp.classDescription
            return NSUniqueIDSpecifier(containerClassDescription: appDescription as! NSScriptClassDescription, containerSpecifier: nil, key: "items", uniqueID: uniqueID)
        }
    }

    // MARK: Secure coding

    static var supportsSecureCoding: Bool { return true }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(5, forKey: "SBQueueItemTagEncodeVersion")

        aCoder.encode(uniqueID, forKey: "SBQueueItemID")
        aCoder.encode(mp4File, forKey: "SBQueueItemMp4File")
        aCoder.encode(fileURL, forKey: "SBQueueItemFileURL")
        aCoder.encode(destURL, forKey: "SBQueueItemDestURL")
        aCoder.encode(attributes, forKey: "SBQueueItemAttributes")
        aCoder.encode(actionsInternal, forKey: "SBQueueItemActions")

        aCoder.encode(statusInternal.rawValue, forKey: "SBQueueItemStatus")
    }

    required init?(coder aDecoder: NSCoder) {
        cancelled = false
        queue = DispatchQueue(label: "org.subler.itemQueue")

        statusInternal = QueueItem.Status(rawValue: Int(aDecoder.decodeInt32(forKey: "SBQueueItemStatus"))) ?? .failed
        mp4File = aDecoder.decodeObject(of: [MP42File.classForCoder()], forKey: "SBQueueItemMp4File") as? MP42File
        uniqueID = aDecoder.decodeObject(of: [NSString.classForCoder()], forKey: "SBQueueItemID") as! String
        attributes = aDecoder.decodeObject(of: [NSDictionary.classForCoder()], forKey: "SBQueueItemAttributes") as! [String : Any]
        fileURL = aDecoder.decodeObject(of: [NSURL.classForCoder()], forKey: "SBQueueItemFileURL") as! URL
        destURL = aDecoder.decodeObject(of: [NSURL.classForCoder()], forKey: "SBQueueItemDestURL") as! URL
        actionsInternal = aDecoder.decodeObject(of: [NSArray.classForCoder(), QueueSetAction.classForCoder(),
                                                     QueueMetadataAction.classForCoder(), QueueSubtitlesAction.classForCoder(),
                                                     QueueSetLanguageAction.classForCoder(), QueueFixFallbacksAction.classForCoder(),
                                                     QueueClearTrackNameAction.classForCoder(), QueueOrganizeGroupsAction.classForCoder(),
                                                     QueueColorSpaceAction.classForCoder(), QueueSetOutputFilenameAction.classForCoder(),
                                                     QueueClearExistingMetadataAction.classForCoder(), QueueOptimizeAction.classForCoder(),
                                                     QueueSendToiTunesAction.classForCoder()], forKey: "SBQueueItemActions") as! [QueueActionProtocol]
    }
}

extension QueueItem.ProcessError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return NSLocalizedString("File not found.", comment: "QueueItem Error")
        case .fileExists:
            return NSLocalizedString("A file already exists at the destination.", comment: "QueueItem Error")
        case .outOfDiskSpace:
            return NSLocalizedString("Not enough disk space.", comment: "QueueItem Error")
        case .optimizationFailure:
            return NSLocalizedString("The file couldn't be optimized.", comment: "QueueItem Error")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return NSLocalizedString("The source file couldn't be found.", comment: "My error")
        case .fileExists:
            return NSLocalizedString("Try to use another name for the destination file.", comment: "QueueItem Error")
        case .outOfDiskSpace:
            return NSLocalizedString("Please free some space on the destination disk.", comment: "QueueItem Error")
        case .optimizationFailure:
            return NSLocalizedString("An error occurred while optimizing the file.", comment: "QueueItem Error")
        }
    }
}
