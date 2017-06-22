//
//  TheTVDB.swift
//  Subler
//
//  Created by Damiano Galassi on 22/06/2017.
//

import Foundation

final public class TheTVDBSwift : SBMetadataImporter {

    private let session = TheTVDBSession.sharedInstance
    private let en = "en"

    override public var languageType: SBMetadataImporterLanguageType {
        get {
            return .ISO;
        }
    }

    override public var languages: [String] {
        get {
            return session.languages
        }
    }

    override public func searchTVSeries(_ seriesName: String, language: String) -> [String] {
        var results: Set<String> = Set()

        let series = session.fetch(series: seriesName, language: language)
        results.formUnion(series.map { $0.seriesName } )

        if language != en {
            let englishResults = searchTVSeries(seriesName, language: en)
            results.formUnion(englishResults)
        }

        return Array(results)
    }

    private func match(series: SeriesSearchResult, name: String) -> Bool {
        if series.seriesName == name {
            return true
        }

        for alias in series.aliases {
            if alias == name {
                return true
            }
        }

        return false
    }

    private func searchIDs(seriesName: String, language: String) -> [Int] {
        let series = session.fetch(series: seriesName, language: language)

        return series.filter { match(series: $0, name: seriesName) }.map { $0.id }
    }

    private func cleanList(actors: [Actor]) -> String {
        return actors.map { $0.name } .reduce("", { $0 + ", " + $1 })
    }

    private func cleanList(names: [String]) -> String {
        return names.reduce("", { $0 + ", " + $1 })
    }

    private func merge(episode: Episode, info: SeriesInfo, actors: [Actor]) -> SBMetadataResult {
        let result = SBMetadataResult()

        result.mediaKind = 10

        // TV Show Info
        result["TheTVDB Series ID"]                  = info.id
        result[SBMetadataResultSeriesName]           = info.seriesName
        result[SBMetadataResultSeriesDescription]    = info.overview
        //result[SBMetadataResultGenre]                = info.genre       // TODO
        result[SBMetadataResultNetwork]              = info.network

        // Episode Info
        result["TheTVDB Episodes ID"]           = episode.id
        result[SBMetadataResultName]            = episode.episodeName
        result[SBMetadataResultReleaseDate]     = episode.firstAired
        result[SBMetadataResultDescription]     = episode.overview
        result[SBMetadataResultLongDescription] = episode.overview

        result[SBMetadataResultSeason]          = episode.airedSeason
        result[SBMetadataResultEpisodeID]       = episode.airedSeason

        result[SBMetadataResultEpisodeID]       = String(format: "%d%02d", episode.airedSeason, episode.airedEpisodeNumber)
        result[SBMetadataResultEpisodeNumber]   = episode.airedEpisodeNumber
        result[SBMetadataResultTrackNumber]     = episode.airedEpisodeNumber

        // Rating
        if let rating = info.rating {
            result[SBMetadataResultRating] = MP42Ratings.defaultManager.ratingStringForiTunesCountry("USA",
                                                                                                     media: "TV",
                                                                                                     ratingString: rating)
        }

        // Actors
        result[SBMetadataResultCast] = cleanList(actors: actors)

        return result
    }

    private func loadEpisodes(info: SeriesInfo, actors: [Actor], season: String, episode: String, language: String) -> [SBMetadataResult] {
        let episodes = session.fetch(episodeForSeriesID: info.id, season: season, episode: episode, language: language)
        let filteredEpisodes = episodes.filter {
            (season.count > 0 ? String($0.airedSeason) == season : true) &&
            (episode.count > 0 ? String($0.airedEpisodeNumber) == episode : true)
        }

        return filteredEpisodes.map { merge(episode: $0, info: info, actors: actors) }
    }

    override public func searchTVSeries(_ seriesName: String, language: String, seasonNum: String, episodeNum: String) -> [SBMetadataResult] {

        let seriesIDs: [Int] =  {
            let result = self.searchIDs(seriesName: seriesName, language: language)
            return result.count > 0 ? result : self.searchIDs(seriesName: seriesName, language: en)
        }()

        var results: [SBMetadataResult] = Array()

        for id in seriesIDs {
            guard let info = session.fetch(seriesInfo: id, language: language) else { continue }
            let actors = session.fetch(actors: id, language: language)
            let episodes = loadEpisodes(info: info, actors: actors, season: seasonNum, episode: episodeNum, language: language)

            results.append(contentsOf: episodes)
        }

        return results
    }

    private func loadTVImage(seriesID: Int, type: String, season: String, language: String) -> [SBRemoteImage] {
        var artworks: [SBRemoteImage] = Array()
        let images: [Image] = {
            let result = session.fetch(images: seriesID, type: type, language: language)
            return result.count > 0 ? result : session.fetch(images: seriesID, type: type, language: en)
        }()

        for image in images {
            guard let fileURL = URL(string: "https://thetvdb.com/banners/" + image.fileName),
                 let thumbURL = URL(string: "https://thetvdb.com/banners/" + image.thumbnail)
                else { continue }

            var selected = true

            if type == season, let subKey = image.subKey, subKey != season {
                    selected = false
            }

            if selected {
                artworks.append(SBRemoteImage(url: fileURL, thumbURL: thumbURL, providerName: "TheTVDB|" + type))
            }
        }
        return artworks
    }

    override public func loadTVMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult? {
        guard let id = metadata["TheTVDB Episodes ID"] as? Int else { return metadata }
        guard let seriesId = metadata["TheTVDB Series ID"] as? Int else { return metadata }

        var artworks: [SBRemoteImage] = Array()

        if let info = session.fetch(episodeInfo: id, language: language) {
            metadata[SBMetadataResultDirector]       = cleanList(names: info.directors);
            metadata[SBMetadataResultScreenwriters]  = cleanList(names: info.writers);

            let guests = cleanList(names: info.guestStars)
            if let actors = metadata[SBMetadataResultCast] as? String {
                if actors.count > 0 && guests.count > 0 {
                    metadata[SBMetadataResultCast] = actors + ", " + guests;
                }
            } else if guests.count > 0 {
                metadata[SBMetadataResultCast] = guests
            }

            if let filename = info.filename, let url = URL(string: "https://thetvdb.com/banners/" + filename) {
                artworks.append(SBRemoteImage(url: url, thumbURL: url, providerName: "TheTVDB|episode"))
            }
        }

        // Get additionals images
        if let season = metadata[SBMetadataResultSeason] as? Int {
            //let iTunesImage = nil
            let seasonImages = loadTVImage(seriesID: seriesId, type: "season", season: String(season), language: language)
            let posterImages = loadTVImage(seriesID: seriesId, type: "poster", season: String(season), language: language)

            artworks.append(contentsOf: seasonImages)
            artworks.append(contentsOf: posterImages)

        }

        metadata.remoteArtworks = artworks;

        return metadata
    }
}
