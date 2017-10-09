//
//  MP42FileAdditions.swift
//  Subler
//
//  Created by Damiano Galassi on 09/10/2017.
//

import Foundation

extension MP42File {
    func hdType() -> Int32? {
        for track in self.tracks(withMediaType: kMP42MediaType_Video) as! [MP42VideoTrack] {
            return isHdVideo(UInt64(track.trackWidth), UInt64(track.trackHeight))
        }
        return nil
    }

    func firstSourceURL() -> URL? {
        return self.tracks.flatMap { $0.url } .first
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
            if let parsed = url.lastPathComponent.parsedAsFilename() {
                return parsed
            }
            else {
                let title = url.deletingPathExtension().lastPathComponent
                return MetadataSearchTerms.movie(title: title)
            }
        }
        return MetadataSearchTerms.none
    }
}
