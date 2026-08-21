//
//  TheTVDB.swift
//  Subler
//
//  Created by Damiano Galassi on 22/06/2017.
//

import Foundation
import MP42Foundation

public struct TheTVDB : MetadataService {

    private let session = TheTVDBService.sharedInstance

    public var languageType: LanguageType {
        get {
            return .ISO_639_2
        }
    }

    public var languages: [String] {
        get {
            return session.languages
        }
    }

    public var defaultLanguage: String {
        return "eng"
    }

    public var name: String {
        return "TheTVDB"
    }

    // MARK: - TV Series name search

    public func search(tvShow: String, language: String) -> [String] {
        var results: Set<String> = Set()

        let series = session.fetch(series: tvShow)
        results.formUnion(series.compactMap { $0.translations?[language] } )

        if results.isEmpty {
            return TheMovieDB().search(tvShow: tvShow, language: language)
        } else {
            return Array(results)
        }
    }

    // MARK: - TV Series ID search

    private func match(series: TVDBSearchResult, name: String) -> Bool {
        if let seriesName = series.name, seriesName.caseInsensitiveCompare(name) == .orderedSame  {
            return true
        }

        if let aliases = series.aliases {
            for alias in aliases {
                if alias.caseInsensitiveCompare(name) == .orderedSame {
                    return true
                }
            }
        }

        return false
    }

    private func searchIDs(seriesName: String) -> [String] {
        let series = session.fetch(series: seriesName)
        let sorted = series.sorted { el1, el2 -> Bool in
            return el1.name?.caseInsensitiveCompare(seriesName) == .orderedSame ? true : false
        }
        let filteredSeries = sorted.filter { $0.status?.isEmpty == false && match(series: $0, name: seriesName) }.map { $0.tvdb_id }

        if filteredSeries.isEmpty == false {
            return filteredSeries
        } else if let firstItemsID = series.first?.tvdb_id {
            return [firstItemsID]
        }
        else {
            return []
        }
    }

    // MARK: - Helpers

    private func cleanList(characters: [TVDBCharacter], type: String) -> String {
        return characters.filter { $0.peopleType == type }
            .map { $0.personName }
            .reduce("", { $0 + ($0.isEmpty ? "" : ", ") + $1 })
    }

    private func cleanList(genres: [TVDBGenreBaseRecord]) -> String {
        return genres.map {$0.name }.reduce("", { $0 + ($0.isEmpty ? "" : ", ") + $1 })
    }

    private func cleanList(ratings: [TVDBContentRating], mediaKind: MediaKind) -> String? {
        if let rating =  ratings.filter({ $0.country == "usa" }).first {
            return Ratings.shared.rating(countryCode: "USA", mediaKind: mediaKind, name: rating.name)?.iTunesCode
        }
        return nil
    }

    private func cleanList(companies: [TVDBCompany]) -> String {
        return companies
            .map { $0.name }
            .reduce("", { $0 + ($0.isEmpty ? "" : ", ") + $1 })
    }

    private func areInIncreasingOrder(ep1: MetadataResult, ep2: MetadataResult) -> Bool {
        guard let v1 = ep1[.episodeNumber] as? Int,
            let v2 = ep2[.episodeNumber] as? Int,
            let s1 = ep1[.season] as? Int,
            let s2 = ep2[.season] as? Int
            else { return false }

        if s1 == s2 {
            return v1 > v2 ? false : true
        }
        else {
            return s1 > s2 ? false : true
        }
    }

    fileprivate func cleanArtworks(_ records: [TVDBArtworBaseRecord]) -> [Artwork] {
        var artworks: [Artwork] = []
        let artworkTypes = session.fetchArtworkTypes()

        for artwork in records {
            let url = URL(string: artwork.image)
            let thumbnailURL = URL(string: artwork.thumbnail)

            var type: ArtworkType?
            var size: ArtworkSize = .default

            let artworkType = artworkTypes.first(where: { $0.id == artwork.type })
            switch (artworkType?.name, artworkType?.recordType) {
            case ("Poster", "movie"):
                type = .poster
            case ("Background", "movie"):
                type = .backdrop
            default:
                break
            }

            switch (artworkType?.width ?? 1, artworkType?.height ?? 1) {
            case (let width, let height) where width == height:
                size = .square
            case (let width, let height) where width >= height:
                size = .rectangle
            case (let width, let height) where height < width:
                size = .default
            default:
                break
            }

            if let url, let thumbnailURL, let type {
                let entry = Artwork(url: url,
                                    thumbURL: thumbnailURL,
                                    service: self.name,
                                    type: type,
                                    size: size)
                artworks.append(entry)
            }
        }

        return artworks
    }

    fileprivate func cleanArtworks(_ records: [TVDBArtworkExtendedRecord]) -> [Artwork] {
        var artworks: [Artwork] = []
        let artworkTypes = session.fetchArtworkTypes()

        for artwork in records {
            let url = URL(string: artwork.image)
            let thumbnailURL = URL(string: artwork.thumbnail)

            var type: ArtworkType?
            var size: ArtworkSize = .default

            let artworkType = artworkTypes.first(where: { $0.id == artwork.type })
            switch (artworkType?.name, artworkType?.recordType) {
            case ("Poster", "series"):
                type = .poster
            case ("Poster", "season"):
                type = .season
            case ("Background", "series"),
                ("Background", "season"):
                type = .backdrop
            default:
                break
            }

            switch (artworkType?.width ?? 1, artworkType?.height ?? 1) {
            case (let width, let height) where width == height:
                size = .square
            case (let width, let height) where width >= height:
                size = .rectangle
            case (let width, let height) where height < width:
                size = .default
            default:
                break
            }

            if let url, let thumbnailURL, let type {
                let entry = Artwork(url: url,
                                    thumbURL: thumbnailURL,
                                    service: self.name,
                                    type: type,
                                    size: size)
                artworks.append(entry)
            }
        }

        return artworks
    }

    private func merge(episode: TVDBEpisodeBaseRecord,
                       info: TVDBSeriesExtendedRecord,
                       translation: TVDBTranslation?,
                       episodeTranslation: TVDBTranslation?) -> MetadataResult {
        let result = MetadataResult()

        result.mediaKind = .tvShow

        // TV Show Info
        result[.serviceContentID]   = info.id
        result[.seriesName]         = translation?.name ?? info.name
        result[.seriesDescription]  = (translation?.overview ?? info.overview)?.trimmingWhitespacesAndNewlinews()
        result[.genre]              = cleanList(genres: info.genres)
        result[.network]            = info.originalNetwork?.name
        result[.rating]             = cleanList(ratings: info.contentRatings, mediaKind: .tvShow)
        result[.cast]               = cleanList(characters: info.characters ?? [], type: "Actor")

        // Episode Info
        result[.serviceEpisodeID] = episode.id
        result[.name]             = episodeTranslation?.name ?? episode.name
        result[.releaseDate]      = episode.aired
        result[.longDescription]  = (episodeTranslation?.overview ?? episode.overview)?.trimmingWhitespacesAndNewlinews()
        result[.season]           = episode.seasonNumber
        result[.episodeID]        = String(format: "%d%02d", episode.seasonNumber, episode.number)
        result[.episodeNumber]    = episode.number
        result[.trackNumber]      = episode.number

        result.remoteArtworks += cleanArtworks(info.artworks)

        // TheTVDB does not provide the following fields normally associated with TV shows in SBMetadataResult:
        // "Copyright", "Comments", "Producers", "Artist"

        return result
    }

    private func loadEpisodes(info: TVDBSeriesExtendedRecord, seasonID: Int?, episodeID: Int?, language: String) -> [MetadataResult] {
        let translation = session.fetch(seriesTranslation: String(info.id), language: language)

        if let seasonID, let episodeID,
           let episode = session.fetch(episodesForSeriesID: info.id, season: seasonID, episode: episodeID).first,
           let episodeTranslation = session.fetch(episodesTranslation: episode.id, language: language) {
            return [merge(episode: episode, info: info, translation: translation, episodeTranslation: episodeTranslation)]
        }
        else {
            let episodes = session.fetch(translatedEpisodesForSeriesID: info.id, season: seasonID, episode: episodeID, language: language)

            let filteredEpisodes = episodes.filter {
                (seasonID != nil ? $0.seasonNumber == seasonID : true) &&
                (episodeID != nil ? $0.number == episodeID : true)
            }

            return filteredEpisodes.map { merge(episode: $0, info: info, translation: translation, episodeTranslation: nil ) }
        }
    }

    // MARK: - Nil values check

    private struct NilValues : OptionSet {
        let rawValue: Int

        static let episodesInfo = NilValues(rawValue: 1)
        static let seriesInfo = NilValues(rawValue: 2)
    }

    private func checkMissingValues(results: [MetadataResult]) -> NilValues {

        var options: NilValues = []

        for result in results {
            if result[.seriesName] == nil {
                options.insert(.seriesInfo)
            }
            if result[.name] == nil {
                options.insert(.episodesInfo)
            }
            if result[.longDescription] == nil {
                options.insert(.episodesInfo)
            }
            if result[.seriesDescription] == nil {
                options.insert(.seriesInfo)
            }
        }

        return options
    }

    private func merge(enResults: [MetadataResult], results: [MetadataResult]) {
        if enResults.count != results.count { return }

        for (index, result) in results.enumerated() {
            let enResult = enResults[index]

            if result[.seriesName] == nil {
                result[.seriesName] = enResult[.seriesName]
            }
            if result[.name] == nil {
                result[.name] = enResult[.name]
            }
            if result[.longDescription] == nil {
                result[.longDescription] = enResult[.longDescription]
                result[.description] = enResult[.description]
            }
            if result[.seriesDescription] == nil {
                result[.seriesDescription] = enResult[.seriesDescription]
            }
        }
    }

    private func merge(info: TVDBSeriesExtendedRecord, results: [MetadataResult]) {
        let name = info.name
        for result in results {
            result[.seriesName] = name
        }

        if let overview = info.overview {
            for result in results {
                result[.seriesDescription] = overview
            }
        }
    }

    // MARK: - TV Search

    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        let seriesIDs: [String] = self.searchIDs(seriesName: tvShow)

        for id in seriesIDs {
            if let info = session.fetch(seriesInfo: id) {
                let availableLanguage = info.overviewTranslations.first(where: { $0 == language }) ??
                    info.overviewTranslations.first(where: { $0 == defaultLanguage }) ??
                    info.overviewTranslations.first ?? defaultLanguage

                let episodes = loadEpisodes(info: info, seasonID: season, episodeID: episode, language: availableLanguage)

                let nilValues = checkMissingValues(results: episodes)

                if language != defaultLanguage {
                    if nilValues.contains(.episodesInfo) {
                        let enResults = loadEpisodes(info: info, seasonID: season, episodeID: episode, language: defaultLanguage)
                        merge(enResults: enResults, results: episodes)
                    }
                }

                return episodes.sorted(by: areInIncreasingOrder)
            }
        }

        return []
    }

    // MARK: - Additional metadata

    private func loadiTunesArtwork(_ metadata: MetadataResult) -> [Artwork] {
        guard let name = metadata[.seriesName] as? String,
            let seasonNum = metadata[.season] as? Int,
            let episodeNum = metadata[.episodeNumber] as? Int,
            let result =  iTunesStore.quickiTunesSearch(tvSeriesName: name, seasonNum: seasonNum, episodeNum: episodeNum)
            else { return [] }

        return result.remoteArtworks
    }

    private func loadSquareTVArtwork(_ metadata: MetadataResult) -> [Artwork] {
        guard let tvShow = metadata[.seriesName] as? String,
            let seasonNum = metadata[.season] as? Int,
            let seriesId = metadata[.serviceContentID] as? Int
            else { return [] }

        return SquaredTVArt().search(tvShow: tvShow, theTVDBSeriesId: seriesId, season: seasonNum)
    }

    private func loadAppleTVArtwork(_ metadata: MetadataResult) -> [Artwork] {
        guard let name = metadata[.seriesName] as? String,
            let season = metadata[.season] as? Int,
            let store = iTunesStore.Store(language: "USA (English)") else { return [] }

        return AppleTV().searchArtwork(term: name, store: store, type: .tvShow(season: season))
    }

    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        guard let id = metadata[.serviceEpisodeID] as? Int else { return metadata }

        var artworks: [Artwork] = []

        if let info = session.fetch(episodeInfo: id, language: language) {
            metadata[.director]       = cleanList(characters: info.characters ?? [], type: "Director")
            metadata[.screenwriters]  = cleanList(characters: info.characters ?? [], type: "Writer")

            let guests = cleanList(characters: info.characters ?? [], type: "Guest Star")
            if let actors = metadata[.cast] as? String {
                if actors.count > 0 && guests.count > 0 {
                    metadata[.cast] = actors + ", " + guests
                }
            } else if guests.count > 0 {
                metadata[.cast] = guests
            }

            if let path = info.image, let url = URL(string: path) {
                artworks.append(Artwork(url: url, thumbURL: url, service: self.name, type: .episode, size: .rectangle))
            }
        }

        // Get additionals images
        if ((metadata[.season] as? Int) != nil) {
            var iTunesImage = [Artwork](), appleTV = [Artwork](), squareTVArt = [Artwork]()
            let group = DispatchGroup()
            DispatchQueue.global().async(group: group) {
                iTunesImage = self.loadiTunesArtwork(metadata)
            }
            DispatchQueue.global().async(group: group) {
                squareTVArt = self.loadSquareTVArtwork(metadata)
            }
            DispatchQueue.global().async(group: group) {
                appleTV = self.loadAppleTVArtwork(metadata)
            }
            group.wait()

            artworks.insert(contentsOf: iTunesImage, at: 0)
            artworks.insert(contentsOf: squareTVArt, at: 0)
            artworks.insert(contentsOf: appleTV, at: 0)
        }

        metadata.remoteArtworks.insert(contentsOf: artworks, at: 0)

        return metadata
    }

    // MARK: - Movie search

    private func metadata(forMoviePartialResult result: TVDBSearchResult, language: String?) -> MetadataResult {
        let metadata = MetadataResult()

        metadata.mediaKind = .movie

        metadata[.serviceContentID] = result.tvdb_id
        metadata[.name]             = result.translations?[language ?? defaultLanguage] ?? result.name
        metadata[.releaseDate]      = result.first_air_time
        metadata[.longDescription]  = (result.overviews?[language ?? defaultLanguage] ?? result.overview)?.trimmingWhitespacesAndNewlinews()
        metadata[.studio]           = result.studios?.first

        return metadata
    }

    public func search(movie: String, language: String) -> [MetadataResult] {
        let results = session.fetch(movie: movie)
        return results.map { metadata(forMoviePartialResult: $0, language: language) }
    }

    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        guard let movieID = metadata[.serviceContentID] as? String,
              let info = session.fetch(movieInfo: movieID)
            else { return metadata }

        metadata[.releaseDate]       = info.first_release?.date
        metadata[.rating]            = cleanList(ratings: info.contentRatings ?? [], mediaKind: .movie)
        metadata[.genre]             = cleanList(genres: info.genres)
        metadata[.studio]            = cleanList(companies: info.companies?.studio ?? [])
        metadata[.cast]              = cleanList(characters: info.characters ?? [], type: "Actor")
        metadata[.director]          = cleanList(characters: info.characters ?? [], type: "Director")
        metadata[.screenwriters]     = cleanList(characters: info.characters ?? [], type: "Writer")
        metadata[.producers]         = cleanList(characters: info.characters ?? [], type: "Producer")
        metadata[.executiveProducer] = cleanList(characters: info.characters ?? [], type: "Executive Producer")
        metadata[.composer]          = cleanList(characters: info.characters ?? [], type: "Original Music Composer")

        metadata[.serviceContentID] = info.id

        var artworks: [Artwork] = []
        artworks += cleanArtworks(info.artworks)

        var iTunesImage = [Artwork](), appleTV = [Artwork]()
        let group = DispatchGroup()
        let queue = DispatchQueue.global()

        queue.async(group: group) {
            // add iTunes artwork
            if let iTunesMetadata = iTunesStore.quickiTunesSearch(movieName: info.name) {
                iTunesImage = iTunesMetadata.remoteArtworks
            }
        }

        queue.async(group: group) {
           if let store = iTunesStore.Store(language: "USA (English)") {
               appleTV = AppleTV().searchArtwork(term: info.name, store: store, type: .movie)
            }
        }
        group.wait()

        artworks.insert(contentsOf: iTunesImage, at: 0)
        artworks.insert(contentsOf: appleTV, at: 0)

        metadata.remoteArtworks = artworks

        return metadata
    }
}
