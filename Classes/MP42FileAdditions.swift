//
//  MP42FileAdditions.swift
//  Subler
//
//  Created by Damiano Galassi on 09/10/2017.
//

import Foundation

extension MP42File {

    enum TrackHDType : Int {
        case hd720p = 1
        case hd1080p = 2
    }

    var hdType: TrackHDType? {
        for track in tracks(withMediaType: kMP42MediaType_Video) as! [MP42VideoTrack] {
            if track.width > 1280 || track.height > 720 {
                return .hd1080p
            } else if track.width >= 960 && track.height >= 720 || track.width >= 1280 {
                return .hd720p
            }
        }
        return nil
    }

    func firstSourceURL() -> URL? {
        for track in tracks {
            if track.url != nil {
                return track.url
            }
        }
        return nil
    }

    func extractSearchTerms(fallbackURL: URL?) -> MetadataSearchTerms {
        if let tvShow = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyTVShow).first?.stringValue,
            let season = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyTVSeason).first?.numberValue?.intValue,
            let number = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyTVEpisodeNumber).first?.numberValue?.intValue {
            return MetadataSearchTerms.tvShow(seriesName: tvShow, season: season, episode: number)
        }
        else if let title = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyName).first?.stringValue,
            let _ = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyReleaseDate).first?.stringValue {
            return MetadataSearchTerms.movie(title: title)
        }
        else if let url = firstSourceURL() ?? fallbackURL {
            let parsed = url.lastPathComponent.parsedAsFilename()

            switch parsed {
            case .none:
                let title = url.deletingPathExtension().lastPathComponent
                return MetadataSearchTerms.movie(title: title)

            case .tvShow, .movie:
                return parsed
            }
        }
        return MetadataSearchTerms.none
    }
}
