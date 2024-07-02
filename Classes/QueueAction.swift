//
//  QueueAction.swift
//  Subler
//
//  Created by Damiano Galassi on 28/07/2017.
//

import Foundation
import MP42Foundation

@objc enum QueueActionType: Int {
    case pre
    case post
}

/**
 *  Queue actions protocol, actions can be run by
 *  the queue's items.
 */
@objc protocol QueueActionProtocol: NSSecureCoding {
    func runAction(_ item: QueueItem) -> Bool
    var localizedDescription: String { get }
    var type: QueueActionType { get }
}

/// An action to remove existing metadata.
class QueueClearExistingMetadataAction: NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Clearing Metadata", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Clear Metadata", comment: "Action description.") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        if let metadata = item.mp4File?.metadata {
            let dataTypes: UInt = MP42MetadataItemDataType.string.rawValue | MP42MetadataItemDataType.stringArray.rawValue | MP42MetadataItemDataType.bool.rawValue | MP42MetadataItemDataType.integer.rawValue | MP42MetadataItemDataType.integerArray.rawValue | MP42MetadataItemDataType.date.rawValue | MP42MetadataItemDataType.image.rawValue

            metadata.removeItems(metadata.metadataItemsFiltered(by: MP42MetadataItemDataType(rawValue: dataTypes)))
            return true
        }
        return false
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }
}

/// An action that set a formatted file name.
class QueueSetOutputFilenameAction: NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Setting Name", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Set Name", comment: "Action description.") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        if let formattedName = item.mp4File?.formattedFileName() {
            let pathExtension = item.destURL.pathExtension
            let destURL = item.destURL.deletingLastPathComponent().appendingPathComponent(formattedName).appendingPathExtension(pathExtension)
            item.destURL = destURL
            return true
        }
        return false
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }
}

/// An action that search in the item source directory for additionals srt subtitles.
class QueueSubtitlesAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Loading subtitles", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Load Subtitles", comment: "Action description.") }

    override init() {}

    private func loadExternalSubtitles(url: URL) -> [MP42FileImporter] {
        let movieFilename = url.deletingPathExtension().lastPathComponent
        var importers: [MP42FileImporter] = []
        if let contents = try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles, .skipsPackageDescendants]) {
            for url in contents {
                let ext = url.pathExtension.lowercased()
                if ext == "srt" || ext == "ass" || ext == "ssa" {
                    let subtitleFilename = url.deletingPathExtension().lastPathComponent
                    if movieFilename.count <= subtitleFilename.count &&
                        subtitleFilename.hasPrefix(movieFilename) {
                        if let importer = try? MP42FileImporter(url: url) {
                            importers.append(importer)
                        }
                    }
                }
            }
        }

        return importers
    }

    func runAction(_ item: QueueItem) -> Bool {
        let subtitlesImporters = loadExternalSubtitles(url: item.fileURL)

        for importer in subtitlesImporters {
            for track in importer.tracks {
                item.mp4File?.addTrack(track)
            }
        }

        return subtitlesImporters.isEmpty == false
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }

}

/// An action that applies a preset to the item.
class QueueSetAction : NSObject, QueueActionProtocol {

    private let preset: MetadataPreset

    init(preset: MetadataPreset) {
        self.preset = preset.copy() as! MetadataPreset
    }

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return String.localizedStringWithFormat(NSLocalizedString("Applying %@ preset", comment: "Action localized description."), preset.title) }
    override var description: String { return String.localizedStringWithFormat(NSLocalizedString("Apply %@ preset", comment: "Action description"), preset.title) }

    func runAction(_ item: QueueItem) -> Bool {
        guard let metadata = item.mp4File?.metadata else { return false }

        let dataTypes: UInt = MP42MetadataItemDataType.string.rawValue | MP42MetadataItemDataType.stringArray.rawValue | MP42MetadataItemDataType.bool.rawValue | MP42MetadataItemDataType.integer.rawValue |
            MP42MetadataItemDataType.integerArray.rawValue | MP42MetadataItemDataType.date.rawValue
        
        let items = preset.metadata.metadataItemsFiltered(by: MP42MetadataItemDataType(rawValue: dataTypes))
        
        if preset.replaceAnnotations {
            metadata.removeItems(metadata.metadataItemsFiltered(by: MP42MetadataItemDataType(rawValue: dataTypes)))
        }
        
        if items.isEmpty == false {
            let identifiers = items.map { $0.identifier }
            metadata.removeItems(metadata.metadataItemsFiltered(byIdentifiers: identifiers))
            metadata.addItems(items)
        }
        
        let artworks = preset.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyCoverArt)
        
        if preset.replaceArtworks {
            metadata.removeItems(metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyCoverArt))
        }
        
        if artworks.isEmpty == false {
            metadata.addItems(artworks)
        }

        return true
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(preset, forKey: "SBQueueActionSet")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let preset = aDecoder.decodeObject(of: MetadataPreset.self, forKey: "SBQueueActionSet") else { return nil }
        self.preset = preset
    }

    static var supportsSecureCoding: Bool { return true }

}

extension Array where Element == Artwork {

    func filter(by type: ArtworkType, size: ArtworkSize, service: String) -> Artwork? {
        if type == .backdrop || type == .episode {
            let serviceArtwork = self.filter { $0.type == type && $0.service == service }.first
            let artwork = self.filter { $0.type == type }.first
            return serviceArtwork != nil ? serviceArtwork : artwork
        }
        else {
            let serviceArtwork = self.filter { $0.type == type && $0.size == size && $0.service == service }.first
            let artwork = self.filter { $0.type == type && $0.size == size}.first
            return serviceArtwork != nil ? serviceArtwork : artwork
        }
    }

}

/// An action that fetches metadata online.
class QueueMetadataAction : NSObject, QueueActionProtocol {

    private let movieLanguage: String
    private let movieProvider: String

    private let tvShowLanguage: String
    private let tvShowProvider: String

    private let preferredArtwork: ArtworkType
    private let preferredArtworkSize: ArtworkSize

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Searching metadata", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Search Metadata", comment: "Action description.") }

    init(movieLanguage: String, tvShowLanguage: String, movieProvider: String, tvShowProvider: String, preferredArtwork: Int, preferredArtworkSize: Int) {
        self.movieLanguage = movieLanguage;
        self.movieProvider = movieProvider;

        self.tvShowLanguage = tvShowLanguage;
        self.tvShowProvider = tvShowProvider

        self.preferredArtwork = ArtworkType(rawValue: preferredArtwork) ?? .poster
        self.preferredArtworkSize = ArtworkSize(rawValue: preferredArtworkSize) ?? .standard

    }

    private func load(artworkURL: URL) -> MP42Image? {
        guard let data = URLSession.data(from: artworkURL) else { return nil }
        return MP42Image(data: data, type: MP42_ART_JPEG)
    }

    private func searchMetadata(info: MetadataSearchTerms) -> MetadataResult? {
        var metadata: MetadataResult? = nil

        switch info {
        case let .movie(title):
            let service = MetadataSearch.service(name: self.movieProvider)
            let movieSearch = MetadataSearch.movieSeach(service: service, movie: title, language: self.movieLanguage)
            _ = movieSearch.search(completionHandler: {
                if let result = $0.first {
                    _ = movieSearch.loadAdditionalMetadata(result, completionHandler: { metadata = $0 }).run()
                }
            }).run()
        case let .tvShow(seriesName, season, episode):
            let service = MetadataSearch.service(name: self.tvShowProvider)
            let tvSearch = MetadataSearch.tvSearch(service: service, tvShow: seriesName, season: season, episode: episode, language: tvShowLanguage)
            _ = tvSearch.search(completionHandler: {
                if let result = $0.first {
                    _ = tvSearch.loadAdditionalMetadata(result, completionHandler: { metadata = $0 }).run()
                }
            }).run()
        case .none:
            break
        }

        return metadata
    }

    private func searchMetadata(terms: MetadataSearchTerms) -> MP42Metadata? {

        guard let metadata = searchMetadata(info: terms) else { return nil }

        let artworks = metadata.remoteArtworks

        if preferredArtwork != .none && artworks.isEmpty == false {
            let artwork: Artwork? = {
                let provider = terms.isMovie ? self.movieProvider : self.tvShowProvider
                let type = terms.isMovie && preferredArtwork.isMovieType == false ? .poster : preferredArtwork
                if let artwork = artworks.filter(by: type, size: preferredArtworkSize, service: provider) {
                    return artwork
                }
                else if let artwork = artworks.filter(by: .season, size: preferredArtworkSize, service: provider) {
                    return artwork
                }
                else if let artwork = artworks.filter(by: .poster, size: .standard, service: provider) {
                    return artwork
                }
                else {
                    return artworks.first
                }
            }()

            if let url = artwork?.url, let artwork = load(artworkURL: url) {
                metadata.artworks.append(artwork)
            }
        }

        let map = metadata.mediaKind == .movie ? MetadataPrefs.movieResultMap : MetadataPrefs.tvShowResultMap
        return metadata.mappedMetadata(to: map, keepEmptyKeys: false)
    }

    func runAction(_ item: QueueItem) -> Bool {
        if let file = item.mp4File {
            let searchTerms = file.extractSearchTerms(fallbackURL: item.fileURL)
            if let metadata = searchMetadata(terms: searchTerms) {

                for item in metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyHDVideo) {
                    metadata.removeItem(item)
                }
                if let type = file.hdType {
                    metadata.addItem(MP42MetadataItem(identifier: MP42MetadataKeyHDVideo,
                                                      value: NSNumber(value: type.rawValue),
                                                      dataType: MP42MetadataItemDataType.integer,
                                                      extendedLanguageTag: nil))
                }

                file.metadata.merge(metadata)
                return true
            }
        }
        return false
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(movieLanguage, forKey: "_movieLanguage")
        aCoder.encode(tvShowLanguage, forKey: "_tvShowLanguage")
        aCoder.encode(movieProvider, forKey: "_movieProvider")
        aCoder.encode(tvShowProvider, forKey: "_tvShowProvider")
        aCoder.encode(Int32(preferredArtwork.rawValue), forKey: "_preferredArtwork")
        aCoder.encode(Int32(preferredArtworkSize.rawValue), forKey: "_preferredArtworkSize")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let movieLanguage = aDecoder.decodeObject(of: NSString.self, forKey: "_movieLanguage") as String?,
            let tvShowLanguage = aDecoder.decodeObject(of: NSString.self, forKey: "_tvShowLanguage") as String?,
            let movieProvider = aDecoder.decodeObject(of: NSString.self, forKey: "_movieProvider") as String?,
            let tvShowProvider = aDecoder.decodeObject(of: NSString.self, forKey: "_tvShowProvider") as String?,
            let preferredArtwork = ArtworkType(rawValue: Int(aDecoder.decodeInt32(forKey: "_preferredArtwork"))),
            let preferredArtworkSize = ArtworkSize(rawValue: Int(aDecoder.decodeInt32(forKey: "_preferredArtworkSize")))
        else { return nil }

        self.movieLanguage = movieLanguage
        self.tvShowLanguage = tvShowLanguage
        self.movieProvider = movieProvider
        self.tvShowProvider = tvShowProvider
        self.preferredArtwork = preferredArtwork
        self.preferredArtworkSize = preferredArtworkSize
    }

    static var supportsSecureCoding: Bool { return true }

}

/// An action that organize the item tracks' groups.
class QueueOrganizeGroupsAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Organizing groups", comment: "Organize Groups action local description") }
    override var description: String { return NSLocalizedString("Organize Groups", comment: "Organize Groups action description") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        item.mp4File?.organizeAlternateGroups()
        item.mp4File?.inferTracksLanguages()
        item.mp4File?.inferMediaCharacteristics()
        return true
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }

}

/// An action that fix the item tracks' fallbacks.
class QueueFixFallbacksAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Fixing Fallbacks", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Fix Fallbacks", comment: "Action description.") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        item.mp4File?.setAutoFallback()
        return true
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }

}

/// An action that set unknown language tracks to preferred one.
class QueueSetLanguageAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Setting tracks language", comment: "Set Language action local description") }
    override var description: String { return NSLocalizedString("Set tracks language", comment: "Set Language action description") }

    let language: String

    init(language: String) {
        self.language = language
    }

    func runAction(_ item: QueueItem) -> Bool {
        if let tracks = item.mp4File?.tracks {
            for track in tracks {
                if track.language == "und" {
                    track.language = language
                }
            }
        }
        return true
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(language, forKey: "SBQueueSetLanguageAction")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let language = aDecoder.decodeObject(of: NSString.self, forKey: "SBQueueSetLanguageAction") as String?
            else { return nil }
        self.language = language
    }

    static var supportsSecureCoding: Bool { return true }

}

/// An action that remove the tracks names.
class QueueClearTrackNameAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Clearing tracks names", comment: "Action localized description") }
    override var description: String { return NSLocalizedString("Clear tracks names", comment: "Action description") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        if let tracks = item.mp4File?.tracks {
            for track in tracks {
                track.name = ""
            }
        }
        return true
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }

}

/// An action that renames audio tracks.
class QueuePrettifyAudioTrackNameAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Prettifying audio track names", comment: "Action localized description") }
    override var description: String { return NSLocalizedString("Prettify audio track names", comment: "Action description") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        if let tracks = item.mp4File?.tracks {

            for track in tracks.compactMap({ $0 as? MP42AudioTrack }) {
                track.name = track.prettyTrackName
            }

        }
        return true
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }

}

/// An action that renames all the chapters titles.
class QueueRenameChaptersAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Prettifying audio track names", comment: "Action localized description") }
    override var description: String { return NSLocalizedString("Prettify audio track names", comment: "Action description") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        let chaptersTracks = item.mp4File?.tracks.compactMap { $0 as? MP42ChapterTrack } ?? []

        chaptersTracks.forEach {
            for (index, chapter) in $0.chapters.enumerated() {
                let title = "Chapter \(index + 1)"
                $0.setTitle(title, forChapter: chapter)
            }
        }

        return true
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }

}

enum QueueColorSpaceActionTag: UInt16 {
    case None = 1
    case Rec601PAL
    case Rec601SMPTEC
    case Rec709
    case Rec2020
    case Rec2100PQ
    case Rec2100HLG
    case P3DCI
    case P3D65
    case sRGB

    func tagValues() -> (colorPrimaries: UInt16, transferCharacteristics: UInt16, matrixCoefficients: UInt16) {
        switch self {
        case .None:
            return (0, 0, 0)
        case .Rec601PAL:
            return (5, 1, 6)
        case .Rec601SMPTEC:
            return (6, 1, 6)
        case .Rec709:
            return (1, 1, 1)
        case .Rec2020:
            return (9, 1, 9)
        case .Rec2100PQ:
            return (9, 16, 9)
        case .Rec2100HLG:
            return (9, 18, 9)
        case .P3DCI:
            return (11, 17, 6)
        case .P3D65:
            return (12, 17, 6)
        case .sRGB:
            return (1, 13, 1)
        }
    }

}

/// An action that set the video track color space.
class QueueColorSpaceAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Setting color space", comment: "Set track color space action local description") }
    override var description: String { return NSLocalizedString("Set color space", comment: "Set track color space action description") }

    let tag: QueueColorSpaceActionTag;

    init(tag: QueueColorSpaceActionTag) {
        self.tag = tag
    }

    func runAction(_ item: QueueItem) -> Bool {
        if let tracks = item.mp4File?.tracks(withMediaType: kMP42MediaType_Video) as? [MP42VideoTrack] {
            for track in tracks {
                if track.format == kMP42VideoCodecType_H264 ||
                    track.format == kMP42VideoCodecType_HEVC ||
                    track.format == kMP42VideoCodecType_HEVC_PSinBitstream ||
                    track.format == kMP42VideoCodecType_VVC ||
                    track.format == kMP42VideoCodecType_VVC_PSinBitstream ||
                    track.format == kMP42VideoCodecType_MPEG4Video ||
                    track.format == kMP42VideoCodecType_AV1 {
                    let values = tag.tagValues()
                    track.colorPrimaries = values.colorPrimaries;
                    track.transferCharacteristics = values.transferCharacteristics;
                    track.matrixCoefficients = values.matrixCoefficients;
                }
            }
            return true
        }
        return false
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(Int32(tag.rawValue), forKey: "SBQueueColorSpaceActionTag")
    }

    required init?(coder aDecoder: NSCoder) {
        self.tag = QueueColorSpaceActionTag(rawValue: UInt16(aDecoder.decodeInt32(forKey: "SBQueueColorSpaceActionTag"))) ?? .Rec709
    }

    static var supportsSecureCoding: Bool { return true }

}

class QueueOptimizeAction: NSObject, QueueActionProtocol {

    var type: QueueActionType { return .post }
    var localizedDescription: String { return NSLocalizedString("Optimizing", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Optimize", comment: "Action description.") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        return item.mp4File?.optimize() ?? false
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }
}

class QueueSendToiTunesAction: NSObject, QueueActionProtocol {

    var type: QueueActionType { return .post }
    var localizedDescription: String { return NSLocalizedString("Sending to iTunes", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Send to iTunes", comment: "Action description.") }

    override init() {}

    func runAction(_ item: QueueItem) -> Bool {
        return sendToFileExternalApp(fileURL: item.destURL)
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }
}

/// An action that changes the 'enabled' audio track to the language preferred, if a track labeled with that language exists
class QueueChangeAudioLanguageAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Enabling audio track with selected language", comment: "Enable audio track local description") }
    override var description: String { return NSLocalizedString("Enabling audio track with selected language", comment: "Enable audio track action description") }

    let language: String

    init(language: String) {
        self.language = language
    }

    func runAction(_ item: QueueItem) -> Bool {
        if let tracks = item.mp4File?.tracks.filter({ $0.mediaType == kMP42MediaType_Audio}) {
            let groups = Dictionary(grouping: tracks, by: { $0.alternateGroup })
            for (_, group) in groups {
                if let track = group.first(where: { $0.language == language && $0.mediaCharacteristicTags.contains("public.main-program-content")}) ?? group.first(where: { $0.language == language }) {
                    tracks.forEach { $0.isEnabled = false }
                    track.isEnabled = true
                }
            }
        }
        return true
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(language, forKey: "SBQueueChangeAudioLanguageAction")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let language = aDecoder.decodeObject(of: NSString.self, forKey: "SBQueueChangeAudioLanguageAction") as String?
            else { return nil }
        self.language = language
    }

    static var supportsSecureCoding: Bool { return true }

}
/// An action that changes the 'enabled' subtitle  track to the language preferred, if a track labeled with that language exists
class QueueChangeSubtitleLanguageAction : NSObject, QueueActionProtocol {

    var type: QueueActionType { return .pre }
    var localizedDescription: String { return NSLocalizedString("Enabling subtitles track with selected language", comment: "Enable subtitles track local description") }
    override var description: String { return NSLocalizedString("Enabling subtitles track with selected language", comment: "Enable subtitles track action description") }

    let language: String

    init(language: String) {
        self.language = language
    }

    func runAction(_ item: QueueItem) -> Bool {
        if let tracks = item.mp4File?.tracks.filter({ $0.mediaType == kMP42MediaType_Subtitle || $0.mediaType == kMP42MediaType_ClosedCaption}) {
            let groups = Dictionary(grouping: tracks, by: { $0.alternateGroup })
            for (_, group) in groups {
                if let track = group.first(where: { $0.language == language && $0.mediaCharacteristicTags.contains("public.main-program-content")}) ?? group.first(where: { $0.language == language }) {
                    tracks.forEach { $0.isEnabled = false }
                    track.isEnabled = true
                }
            }
        }
        return true
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(language, forKey: "SBQueueChangeSubtitleLanguageAction")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let language = aDecoder.decodeObject(of: NSString.self, forKey: "SBQueueChangeSubtitleLanguageAction") as String?
            else { return nil }
        self.language = language
    }

    static var supportsSecureCoding: Bool { return true }
}
