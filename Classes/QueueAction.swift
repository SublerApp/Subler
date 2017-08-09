//
//  QueueAction.swift
//  Subler
//
//  Created by Damiano Galassi on 28/07/2017.
//

import Foundation

extension Array where Element == Artwork {

    func artwork(by type: ArtworkType, service: String) -> Artwork? {
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
            let artwork = self.filter { $0.type == type && $0.service == service }.first

            return serviceArtwork != nil ? serviceArtwork : artwork
        }
    }

}

/// An actions that fetches metadata online.
@objc(SBQueueMetadataAction) class QueueMetadataAction : NSObject, SBQueueActionProtocol {

    private let movieLanguage: String
    private let movieProvider: String

    private let tvShowLanguage: String
    private let tvShowProvider: String

    private let preferredArtwork: ArtworkType

    let localizedDescription: String = NSLocalizedString("Searching metadata", comment: "Action localized description.")
    override var description: String { get { return NSLocalizedString("Search Metadata", comment: "Action description.") } }

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

    private func searchMetadata(info: FilenameInfo) -> MetadataResult? {
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
            let tvSearch = MetadataSearch.tvSearch(service: service, tvSeries: seriesName, season: season, episode: episode, language: tvShowLanguage)
            _ = tvSearch.search(completionHandler: {
                if let result = $0.first {
                    _ = tvSearch.loadAdditionalMetadata(result, completionHandler: { metadata = $0 }).run()
                }
            }).run()
        }

        return metadata
    }

    private func searchMetadata(url: URL) -> MP42Metadata? {

        guard let info = url.lastPathComponent.parsedAsFilename(),
              let metadata = searchMetadata(info: info) else { return nil }

        let artworks = metadata.remoteArtworks
        if artworks.isEmpty == false {
            let artwork: Artwork? = {
                let provider = info.isMovie ? self.movieProvider : self.tvShowProvider
                if let artwork = artworks.artwork(by: preferredArtwork, service: provider) {
                    return artwork
                }
                else if let artwork = artworks.artwork(by: .poster, service: provider) {
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
        if let map = metadata.mediaKind == 9 ? defaults.map(forKey: "SBMetadataMovieResultMap")
            : defaults.map(forKey: "SBMetadataTvShowResultMap") {
            return metadata.mappedMetadata(to: map, keepEmptyKeys: false)
        }
        return nil
    }

    func runAction(_ item: SBQueueItem) {
        if let file = item.mp4File, let metadata = searchMetadata(url: item.fileURL) {

            for track in file.tracks(withMediaType: kMP42MediaType_Video) {
                if let track = track as? MP42VideoTrack {
                    let hdVideo = isHdVideo(UInt64(track.trackWidth), UInt64(track.trackHeight))
                    if hdVideo > 0 {
                        
                        for item in metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyHDVideo) {
                            metadata.removeItem(item)
                        }
                        
                        metadata.addItem(MP42MetadataItem(identifier: MP42MetadataKeyHDVideo,
                                                          value: NSNumber(value: hdVideo),
                                                          dataType: MP42MetadataItemDataType.integer,
                                                          extendedLanguageTag: nil))
                    }
                }
            }
            
            file.metadata.merge(metadata)
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

    static var supportsSecureCoding: Bool { get { return true } }

}
