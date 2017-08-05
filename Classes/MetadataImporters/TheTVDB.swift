//
//  TheTVDB.swift
//  Subler
//
//  Created by Damiano Galassi on 22/06/2017.
//

import Foundation

public struct TheTVDB : MetadataService, MetadataNameService {

    private let session = TheTVDBService.sharedInstance
    private static let bannerPath = "https://thetvdb.com/banners/"

    public var languageType: LanguageType {
        get {
            return .ISO
        }
    }

    public var languages: [String] {
        get {
            return session.languages
        }
    }

    public var defaultLanguage: String {
        return "en"
    }

    public var name: String {
        return "TheTVDB"
    }

    // MARK: - TV Series name search

    public func search(TVSeries: String, language: String) -> [String] {
        var results: Set<String> = Set()

        let series = session.fetch(series: TVSeries, language: language)
        results.formUnion(series.map { $0.seriesName } )

        if language != defaultLanguage {
            let englishResults = search(TVSeries: TVSeries, language: defaultLanguage)
            results.formUnion(englishResults)
        }

        return Array(results)
    }

    // MARK: - TV Series ID search

    private func match(series: TVDBSeriesSearchResult, name: String) -> Bool {
        if series.seriesName.caseInsensitiveCompare(name) == .orderedSame  {
            return true
        }

        for alias in series.aliases {
            if alias.caseInsensitiveCompare(name) == .orderedSame {
                return true
            }
        }

        return false
    }

    private func searchIDs(seriesName: String, language: String) -> [Int] {
        let series = session.fetch(series: seriesName, language: language)
        let filteredSeries = series.filter { match(series: $0, name: seriesName) }.map { $0.id }

        if filteredSeries.count > 0 {
            return filteredSeries
        }
        else if let firstItemsID = series.first?.id {
            return [firstItemsID]
        }
        else {
            return []
        }
    }

    // MARK: - Helpers

    private func cleanList(actors: [TVDBActor]) -> String {
        return actors.map { $0.name } .reduce("", { $0 + ($0.count > 0 ? ", " : "") + $1 })
    }

    private func cleanList(names: [String]) -> String {
        return names.reduce("", { $0 + ($0.count > 0 ? ", " : "") + $1 })
    }

    private func areInIncreasingOrder(ep1: SBMetadataResult, ep2: SBMetadataResult) -> Bool {
        guard let v1 = ep1[SBMetadataResultEpisodeNumber] as? Int,
            let v2 = ep2[SBMetadataResultEpisodeNumber] as? Int,
            let s1 = ep1[SBMetadataResultSeason] as? Int,
            let s2 = ep2[SBMetadataResultSeason] as? Int
            else { return false }

        if s1 == s2 {
            return v1 > v2 ? false : true
        }
        else {
            return s1 > s2 ? false : true
        }
    }

    private func merge(episode: TVDBEpisode, info: TVDBSeriesInfo, actors: [TVDBActor]) -> SBMetadataResult {
        let result = SBMetadataResult()

        result.mediaKind = 10

        // TV Show Info
        result["TheTVDB Series ID"]                = info.id
        result[SBMetadataResultSeriesName]         = info.seriesName
        result[SBMetadataResultSeriesDescription]  = info.overview
        result[SBMetadataResultGenre]              = cleanList(names: info.genre)
        result[SBMetadataResultNetwork]            = info.network

        // Episode Info
        result["TheTVDB Episodes ID"]           = episode.id
        result[SBMetadataResultName]            = episode.episodeName
        result[SBMetadataResultReleaseDate]     = episode.firstAired
        result[SBMetadataResultDescription]     = episode.overview
        result[SBMetadataResultLongDescription] = episode.overview

        result[SBMetadataResultSeason]          = episode.airedSeason

        result[SBMetadataResultEpisodeID]       = String(format: "%d%02d", episode.airedSeason, episode.airedEpisodeNumber)
        result[SBMetadataResultEpisodeNumber]   = episode.airedEpisodeNumber
        result[SBMetadataResultTrackNumber]     = episode.airedEpisodeNumber

        // Rating
        if let rating = info.rating, rating.count > 0 {
            result[SBMetadataResultRating] = MP42Ratings.defaultManager.ratingStringForiTunesCountry("USA",
                                                                                                     media: "TV",
                                                                                                     ratingString: rating)
        }

        // Actors
        result[SBMetadataResultCast] = cleanList(actors: actors)

        // TheTVDB does not provide the following fields normally associated with TV shows in SBMetadataResult:
        // "Copyright", "Comments", "Producers", "Artist"

        return result
    }

    private func loadEpisodes(info: TVDBSeriesInfo, actors: [TVDBActor], season: Int?, episode: Int?, language: String) -> [SBMetadataResult] {
        let episodes = session.fetch(episodeForSeriesID: info.id, season: season, episode: episode, language: language)
        let filteredEpisodes = episodes.filter {
            (season != nil ? $0.airedSeason == season : true) &&
            (episode != nil ? $0.airedEpisodeNumber == episode : true)
        }

        return filteredEpisodes.map { merge(episode: $0, info: info, actors: actors) }
    }

    // MARK: - Nil values check

    private struct NilValues : OptionSet {
        let rawValue: Int

        static let episodesInfo = NilValues(rawValue: 1)
        static let seriesInfo = NilValues(rawValue: 2)
    }

    private func checkMissingValues(results: [SBMetadataResult]) -> NilValues {

        var options: NilValues = []

        for result in results {
            if result[SBMetadataResultSeriesName] == nil {
                options.insert(.seriesInfo)
            }
            if result[SBMetadataResultName] == nil {
                options.insert(.episodesInfo)
            }
            if result[SBMetadataResultLongDescription] == nil {
                options.insert(.episodesInfo)
            }
            if result[SBMetadataResultSeriesDescription] == nil {
                options.insert(.seriesInfo)
            }
        }

        return options
    }

    private func merge(enResults: [SBMetadataResult], results: [SBMetadataResult]) {
        if enResults.count != results.count { return }

        for (index, result) in results.enumerated() {
            let enResult = enResults[index]

            if result[SBMetadataResultSeriesName] == nil {
                result[SBMetadataResultSeriesName] = enResult[SBMetadataResultSeriesName]
            }
            if result[SBMetadataResultName] == nil {
                result[SBMetadataResultName] = enResult[SBMetadataResultName]
            }
            if result[SBMetadataResultLongDescription] == nil {
                result[SBMetadataResultLongDescription] = enResult[SBMetadataResultLongDescription]
                result[SBMetadataResultDescription] = enResult[SBMetadataResultDescription]
            }
            if result[SBMetadataResultSeriesDescription] == nil {
                result[SBMetadataResultSeriesDescription] = enResult[SBMetadataResultSeriesDescription]
            }
        }
    }

    private func merge(info: TVDBSeriesInfo, results: [SBMetadataResult]) {
        let name = info.seriesName
        for result in results {
            result[SBMetadataResultSeriesName] = name
        }

        if let overview = info.overview {
            for result in results {
                result[SBMetadataResultSeriesDescription] = overview
            }
        }
    }

    // MARK: - TV Search

    public func search(TVSeries: String, language: String, season: Int?, episode: Int?) -> [SBMetadataResult] {
        let seriesIDs: [Int] =  {
            let result = self.searchIDs(seriesName: TVSeries, language: language)
            return result.count > 0 ? result : self.searchIDs(seriesName: TVSeries, language: defaultLanguage)
        }()

        var results: [SBMetadataResult] = Array()

        for id in seriesIDs {
            guard let info: TVDBSeriesInfo = {
                let result = session.fetch(seriesInfo: id, language: language)
                return result != nil ? result : session.fetch(seriesInfo: id, language: defaultLanguage)
                }()
                else { continue }
            let actors = session.fetch(actors: id, language: language)
            let episodes = loadEpisodes(info: info, actors: actors, season: season, episode: episode, language: language)

            let nilValues = checkMissingValues(results: episodes)

            if language != defaultLanguage {
                if nilValues.contains(.seriesInfo),
                    let enInfo = session.fetch(seriesInfo: id, language: defaultLanguage) {
                    merge(info: enInfo, results: episodes)
                }

                if nilValues.contains(.episodesInfo) {
                    let enResults = loadEpisodes(info: info, actors: actors, season: season, episode: episode, language: defaultLanguage)
                    merge(enResults: enResults, results: episodes)
                }
            }

            results.append(contentsOf: episodes)
        }

        return results.sorted(by: areInIncreasingOrder)
    }

    // MARK: - Additional metadata

    private func loadiTunesArtwork(_ metadata: SBMetadataResult) -> [RemoteImage] {
        guard let name = metadata[SBMetadataResultSeriesName] as? String,
            let seasonNum = metadata[SBMetadataResultSeason] as? Int,
            let episodeNum = metadata[SBMetadataResultEpisodeNumber] as? Int,
            let result =  iTunesStore.quickiTunesSearch(tvSeriesName: name, seasonNum: seasonNum, episodeNum: episodeNum)
            else { return [] }

        return result.remoteArtworks?.toStruct() ?? []
    }

    private func loadTVArtwork(seriesID: Int, type: TVDBArtworkType, season: String, language: String) -> [RemoteImage] {
        var artworks: [RemoteImage] = Array()
        let images: [TVDBImage] = {
            var result = session.fetch(images: seriesID, type: type, language: language)
            if result.count == 0 || language != defaultLanguage {
                result.append(contentsOf: session.fetch(images: seriesID, type: type, language: defaultLanguage))
            }
            return result
        }()

        for image in images {
            guard let fileURL = URL(string: TheTVDB.bannerPath + image.fileName),
                 let thumbURL = URL(string: TheTVDB.bannerPath + image.thumbnail)
                else { continue }

            var selected = true

            if type == .season, let subKey = image.subKey, subKey != season {
                selected = false
            }

            if selected {
                artworks.append(RemoteImage(url: fileURL, thumbURL: thumbURL, providerName: "TheTVDB|" + type.rawValue))
            }
        }
        return artworks
    }

    public func loadTVMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult {
        guard let id = metadata["TheTVDB Episodes ID"] as? Int else { return metadata }
        guard let seriesId = metadata["TheTVDB Series ID"] as? Int else { return metadata }

        var artworks: [RemoteImage] = Array()

        if let info = session.fetch(episodeInfo: id, language: language) {
            metadata[SBMetadataResultDirector]       = cleanList(names: info.directors)
            metadata[SBMetadataResultScreenwriters]  = cleanList(names: info.writers)

            let guests = cleanList(names: info.guestStars)
            if let actors = metadata[SBMetadataResultCast] as? String {
                if actors.count > 0 && guests.count > 0 {
                    metadata[SBMetadataResultCast] = actors + ", " + guests
                }
            } else if guests.count > 0 {
                metadata[SBMetadataResultCast] = guests
            }

            if let filename = info.filename, let url = URL(string: TheTVDB.bannerPath + filename) {
                artworks.append(RemoteImage(url: url, thumbURL: url, providerName: "TheTVDB|episode"))
            }
        }

        // Get additionals images
        if let season = metadata[SBMetadataResultSeason] as? Int {
            let iTunesImage = loadiTunesArtwork(metadata)
            let seasonImages = loadTVArtwork(seriesID: seriesId, type: .season, season: String(season), language: language)
            let posterImages = loadTVArtwork(seriesID: seriesId, type: .poster, season: String(season), language: language)

            artworks.insert(contentsOf: iTunesImage, at: 0)
            artworks.append(contentsOf: seasonImages)
            artworks.append(contentsOf: posterImages)
        }

        metadata.remoteArtworks = artworks.toClass()

        return metadata
    }

    // MARK: - Unimplemented movie search

    public func search(movie: String, language: String) -> [SBMetadataResult] {
        return []
    }

    public func loadMovieMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult {
        return metadata
    }
}
