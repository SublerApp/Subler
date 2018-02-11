//
//  QueueAction.swift
//  Subler
//
//  Created by Damiano Galassi on 28/07/2017.
//

import Foundation

/// SBQueue actions protocol, actions can be run by the queue's items.
//@objc(SBQueueActionProtocol) protocol QueueActionProtocol: NSSecureCoding {
//    @objc func runAction(_ item: SBQueueItem)
//    @objc var localizedDescription: String { get }
//}

/// An action that set a formatted file name.
@objc(SBQueueSetOutputFilenameAction) class QueueSetOutputFilenameAction: NSObject, SBQueueActionProtocol {

    var localizedDescription: String { return NSLocalizedString("Setting Name", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Set Name", comment: "Action description.") }

    @objc override init() {}

    func runAction(_ item: SBQueueItem) {
        if let formattedName = item.mp4File?.formattedFileName() {
            let pathExtension = item.destURL.pathExtension
            let destURL = item.destURL.deletingLastPathComponent().appendingPathComponent(formattedName).appendingPathExtension(pathExtension)
            item.destURL = destURL
        }
    }

    func encode(with aCoder: NSCoder) {}
    required init?(coder aDecoder: NSCoder) {}
    static var supportsSecureCoding: Bool { return true }
}

/// An action that search in the item source directory for additionals srt subtitles.
@objc(SBQueueSubtitlesAction) class QueueSubtitlesAction : NSObject, SBQueueActionProtocol {

    var localizedDescription: String { return NSLocalizedString("Loading subtitles", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Load Subtitles", comment: "Action description.") }

    @objc override init() {}

    private func loadExternalSubtitles(url: URL) -> [MP42FileImporter] {
        let movieFilename = url.deletingPathExtension().lastPathComponent
        var importers: [MP42FileImporter] = Array()
        if let contents = try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles, .skipsPackageDescendants]) {
            for url in contents {
                let ext = url.pathExtension.lowercased()
                if ext == "srt" || ext == "ass" || ext == "ssa" {
                    let subtitleFilename = url.deletingPathExtension().lastPathComponent
                    if movieFilename.count < subtitleFilename.count &&
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

    func runAction(_ item: SBQueueItem) {
        let subtitlesImporters = loadExternalSubtitles(url: item.fileURL)

        for importer in subtitlesImporters {
            for track in importer.tracks {
                item.mp4File?.addTrack(track)
            }
        }
    }

    func encode(with aCoder: NSCoder) {}

    required init?(coder aDecoder: NSCoder) {}

    static var supportsSecureCoding: Bool { return true }

}

/// An action that applies a preset to the item.
@objc(SBQueueSetAction) class QueueSetAction : NSObject, SBQueueActionProtocol {

    private let preset: MetadataPreset

    @objc init(preset: MetadataPreset) {
        self.preset = preset.copy() as! MetadataPreset
    }

    var localizedDescription: String { return String.localizedStringWithFormat(NSLocalizedString("Applying %@ preset", comment: "Action localized description."), preset.title) }
    override var description: String { return String.localizedStringWithFormat(NSLocalizedString("Apply %@ preset", comment: "Action description"), preset.title) }

    func runAction(_ item: SBQueueItem) {
        guard let metadata = item.mp4File?.metadata else { return }

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

    func filter(by type: ArtworkType, service: String) -> Artwork? {
        let iTunesServiceName = iTunesStore().name

        // Special case for iTunes
        if service == iTunesServiceName {
            return self.first
        }
        else if type == ArtworkType.iTunes {
            return self.filter { $0.service == iTunesServiceName }.first
        }
        else {
            let serviceArtwork = self.filter { $0.type == type && $0.service == service }.first
            let artwork = self.filter { $0.type == type }.first

            return serviceArtwork != nil ? serviceArtwork : artwork
        }
    }

}

/// An action that fetches metadata online.
@objc(SBQueueMetadataAction) class QueueMetadataAction : NSObject, SBQueueActionProtocol {

    private let movieLanguage: String
    private let movieProvider: String

    private let tvShowLanguage: String
    private let tvShowProvider: String

    private let preferredArtwork: ArtworkType

    var localizedDescription: String { return NSLocalizedString("Searching metadata", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Search Metadata", comment: "Action description.") }

    @objc init(movieLanguage: String, tvShowLanguage: String, movieProvider: String, tvShowProvider: String, preferredArtwork: ArtworkType) {
        self.movieLanguage = movieLanguage;
        self.movieProvider = movieProvider;

        self.tvShowLanguage = tvShowLanguage;
        self.tvShowProvider = tvShowProvider

        self.preferredArtwork = preferredArtwork
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
        if artworks.isEmpty == false {
            let artwork: Artwork? = {
                let provider = terms.isMovie ? self.movieProvider : self.tvShowProvider
                if let artwork = artworks.filter(by: preferredArtwork, service: provider) {
                    return artwork
                }
                else if let artwork = artworks.filter(by: .season, service: provider) {
                    return artwork
                }
                else if let artwork = artworks.filter(by: .poster, service: provider) {
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

        let defaults = UserDefaults.standard
        if let map = metadata.mediaKind == .movie ? defaults.map(forKey: "SBMetadataMovieResultMap")
            : defaults.map(forKey: "SBMetadataTvShowResultMap") {
            return metadata.mappedMetadata(to: map, keepEmptyKeys: false)
        }
        return nil
    }

    func runAction(_ item: SBQueueItem) {
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
            }
        }
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(movieLanguage, forKey: "_movieLanguage")
        aCoder.encode(tvShowLanguage, forKey: "_tvShowLanguage")
        aCoder.encode(movieProvider, forKey: "_movieProvider")
        aCoder.encode(tvShowProvider, forKey: "_tvShowProvider")
        aCoder.encode(Int32(preferredArtwork.rawValue), forKey: "_preferredArtwork")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let movieLanguage = aDecoder.decodeObject(of: NSString.self, forKey: "_movieLanguage") as String?,
            let tvShowLanguage = aDecoder.decodeObject(of: NSString.self, forKey: "_tvShowLanguage") as String?,
            let movieProvider = aDecoder.decodeObject(of: NSString.self, forKey: "_movieProvider") as String?,
            let tvShowProvider = aDecoder.decodeObject(of: NSString.self, forKey: "_tvShowProvider") as String?,
            let preferredArtwork = ArtworkType(rawValue: Int(aDecoder.decodeInt32(forKey: "_preferredArtwork")))
        else { return nil }

        self.movieLanguage = movieLanguage
        self.tvShowLanguage = tvShowLanguage
        self.movieProvider = movieProvider
        self.tvShowProvider = tvShowProvider
        self.preferredArtwork = preferredArtwork
    }

    static var supportsSecureCoding: Bool { return true }

}

/// An action that organize the item tracks' groups.
@objc(SBQueueOrganizeGroupsAction) class QueueOrganizeGroupsAction : NSObject, SBQueueActionProtocol {

    var localizedDescription: String { return NSLocalizedString("Organizing groups", comment: "Organize Groups action local description") }
    override var description: String { return NSLocalizedString("Organize Groups", comment: "Organize Groups action description") }

    @objc override init() {}

    func runAction(_ item: SBQueueItem) {
        item.mp4File?.organizeAlternateGroups()
        item.mp4File?.inferMediaCharacteristics()
    }

    func encode(with aCoder: NSCoder) {}

    required init?(coder aDecoder: NSCoder) {}

    static var supportsSecureCoding: Bool { return true }

}

/// An action that fix the item tracks' fallbacks.
@objc(SBQueueFixFallbacksAction) class QueueFixFallbacksAction : NSObject, SBQueueActionProtocol {

    var localizedDescription: String { return NSLocalizedString("Fixing Fallbacks", comment: "Action localized description.") }
    override var description: String { return NSLocalizedString("Fix Fallbacks", comment: "Action description.") }

    @objc override init() {}

    func runAction(_ item: SBQueueItem) {
        item.mp4File?.setAutoFallback()
    }

    func encode(with aCoder: NSCoder) {}

    required init?(coder aDecoder: NSCoder) {}

    static var supportsSecureCoding: Bool { return true }

}

/// An action that set unknown language tracks to preferred one.
@objc(SBQueueSetLanguageAction) class QueueSetLanguageAction : NSObject, SBQueueActionProtocol {

    var localizedDescription: String { return NSLocalizedString("Setting tracks language", comment: "Set Language action local description") }
    override var description: String { return NSLocalizedString("Set tracks language", comment: "Set Language action description") }

    let language: String

    @objc init(language: String) {
        self.language = language
    }

    func runAction(_ item: SBQueueItem) {
        if let tracks = item.mp4File?.tracks {
            for track in tracks {
                if track.language == "und" {
                    track.language = language
                }
            }
        }
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
@objc(SBQueueClearTrackNameAction) class QueueClearTrackNameAction : NSObject, SBQueueActionProtocol {

    var localizedDescription: String { return NSLocalizedString("Clearing tracks names", comment: "Action localized description") }
    override var description: String { return NSLocalizedString("Clear tracks names", comment: "Action description") }

    @objc override init() {}

    func runAction(_ item: SBQueueItem) {
        if let tracks = item.mp4File?.tracks {
            for track in tracks {
                track.name = ""
            }
        }
    }

    func encode(with aCoder: NSCoder) {}

    required init?(coder aDecoder: NSCoder) {}

    static var supportsSecureCoding: Bool { return true }

}

@objc(SBQueueColorSpaceActionTag) enum QueueColorSpaceActionTag: UInt16 {
    case SBQueueColorSpaceActionTagNone = 1
    case SBQueueColorSpaceActionTagRec601PAL
    case SBQueueColorSpaceActionTagRec601SMPTEC
    case SBQueueColorSpaceActionTagRec709
    case SBQueueColorSpaceActionTagRec2020
}

/// An action that set the video track color space.
@objc(SBQueueColorSpaceAction) class QueueColorSpaceAction : NSObject, SBQueueActionProtocol {

    var localizedDescription: String { return NSLocalizedString("Setting color space", comment: "Set track color space action local description") }
    override var description: String { return NSLocalizedString("Set color space", comment: "Set track color space action description") }

    let colorPrimaries: UInt16;
    let transferCharacteristics: UInt16;
    let matrixCoefficients: UInt16;

    @objc init(tag: QueueColorSpaceActionTag) {
        switch tag {
        case .SBQueueColorSpaceActionTagNone:
            self.colorPrimaries = 0
            self.transferCharacteristics = 0
            self.matrixCoefficients = 0
        case .SBQueueColorSpaceActionTagRec601PAL:
            self.colorPrimaries = 5
            self.transferCharacteristics = 1
            self.matrixCoefficients = 6
        case .SBQueueColorSpaceActionTagRec601SMPTEC:
            self.colorPrimaries = 6
            self.transferCharacteristics = 1
            self.matrixCoefficients = 6
        case .SBQueueColorSpaceActionTagRec709:
            self.colorPrimaries = 1
            self.transferCharacteristics = 1
            self.matrixCoefficients = 1
        case .SBQueueColorSpaceActionTagRec2020:
            self.colorPrimaries = 9
            self.transferCharacteristics = 1
            self.matrixCoefficients = 9
        }
    }

    func runAction(_ item: SBQueueItem) {
        if let tracks = item.mp4File?.tracks(withMediaType: kMP42MediaType_Video) as? [MP42VideoTrack] {
            for track in tracks {
                if track.format == kMP42VideoCodecType_H264 ||
                    track.format == kMP42VideoCodecType_HEVC ||
                    track.format == kMP42VideoCodecType_HEVC_PSinBitstream ||
                    track.format == kMP42VideoCodecType_MPEG4Video {
                    track.colorPrimaries = colorPrimaries;
                    track.transferCharacteristics = transferCharacteristics;
                    track.matrixCoefficients = matrixCoefficients;
                }
            }
        }
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(Int32(colorPrimaries), forKey: "SBQueueColorSpaceActionColorPrimaries")
        aCoder.encode(Int32(transferCharacteristics), forKey: "SBQueueColorSpaceActionTransferCharacteristics")
        aCoder.encode(Int32(matrixCoefficients), forKey: "SBQueueColorSpaceActionMatrixCoefficients")
    }

    required init?(coder aDecoder: NSCoder) {
        self.colorPrimaries = UInt16(aDecoder.decodeInt32(forKey: "SBQueueColorSpaceActionColorPrimaries"))
        self.transferCharacteristics = UInt16(aDecoder.decodeInt32(forKey: "SBQueueColorSpaceActionTransferCharacteristics"))
        self.matrixCoefficients = UInt16(aDecoder.decodeInt32(forKey: "SBQueueColorSpaceActionMatrixCoefficients"))
    }

    static var supportsSecureCoding: Bool { return true }

}
