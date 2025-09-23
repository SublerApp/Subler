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

    public func search(tvShow: String, language: String) -> [String] {
        var results: Set<String> = Set()

        let series = session.fetch(series: tvShow, language: language)
        results.formUnion(series.compactMap { $0.seriesName } )

        if language != defaultLanguage {
            let englishResults = search(tvShow: tvShow, language: defaultLanguage)
            results.formUnion(englishResults)
        }

        if results.isEmpty {
            return TheMovieDB().search(tvShow: tvShow, language: language)
        } else {
            return Array(results)
        }
    }

    // MARK: - TV Series ID search

    private func match(series: TVDBSeriesSearchResult, name: String) -> Bool {
        if let name = series.seriesName, name.caseInsensitiveCompare(name) == .orderedSame  {
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
        let sorted = series.sorted { el1, el2 -> Bool in
            return el1.seriesName?.caseInsensitiveCompare(seriesName) == .orderedSame ? true : false
        }
        let filteredSeries = sorted.filter { $0.status.isEmpty == false && match(series: $0, name: seriesName) }.map { $0.id }

        if filteredSeries.isEmpty == false {
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
        return actors.map { $0.name } .reduce("", { $0 + ($0.isEmpty ? "" : ", ") + $1 })
    }

    private func cleanList(names: [String]) -> String {
        return names.reduce("", { $0 + ($0.isEmpty ? "" : ", ") + $1 })
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

    private func merge(episode: TVDBEpisode, info: TVDBSeriesInfo, actors: [TVDBActor]) -> MetadataResult {
        let result = MetadataResult()

        result.mediaKind = .tvShow

        // TV Show Info
        result[.serviceContentID]    = info.id
        result[.seriesName]         = info.seriesName
        result[.seriesDescription]  = info.overview?.trimmingWhitespacesAndNewlinews()
        result[.genre]              = cleanList(names: info.genre)
        result[.network]            = info.network

        // Episode Info
        result[.serviceEpisodeID] = episode.id
        result[.name]             = episode.episodeName
        result[.releaseDate]      = episode.firstAired
        result[.longDescription]  = episode.overview?.trimmingWhitespacesAndNewlinews()

        result[.season]           = episode.airedSeason

        result[.episodeID]        = String(format: "%d%02d", episode.airedSeason, episode.airedEpisodeNumber)
        result[.episodeNumber]    = episode.airedEpisodeNumber
        result[.trackNumber]      = episode.airedEpisodeNumber

        // Rating
        if let rating = info.rating, rating.count > 0 {
            result[.rating] = Ratings.shared.rating(countryCode: "USA", mediaKind: .tvShow, name: rating)?.iTunesCode
        }

        // Actors
        result[.cast] = cleanList(actors: actors)

        // TheTVDB does not provide the following fields normally associated with TV shows in SBMetadataResult:
        // "Copyright", "Comments", "Producers", "Artist"

        return result
    }

    private func loadEpisodes(info: TVDBSeriesInfo, actors: [TVDBActor], season: Int?, episode: Int?, language: String) -> [MetadataResult] {
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

    private func merge(info: TVDBSeriesInfo, results: [MetadataResult]) {
        let name = info.seriesName
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
        let seriesIDs: [Int] =  {
            let result = self.searchIDs(seriesName: tvShow, language: language)
            if result.isEmpty {
                let enResults = self.searchIDs(seriesName: tvShow, language: defaultLanguage)
                if enResults.isEmpty {
                    let tmdb = TheMovieDB()
                    let tvShowsTMDB = tmdb.search(tvShow: tvShow, language: language)
                    if let tvShowTMDB = tvShowsTMDB.first {
                        return self.searchIDs(seriesName: tvShowTMDB, language: language)
                    }
                }
                return enResults
            }
            return result
        }()

        var results: [MetadataResult] = []

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

            results.append(contentsOf: episodes.sorted(by: areInIncreasingOrder))
            break
        }

        return results
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

    private func loadTVArtwork(seriesID: Int, type: ArtworkType, season: String, language: String) -> [Artwork] {
        var artworks: [Artwork] = []
        let images: [TVDBImage] = {
            var result = session.fetch(images: seriesID, type: type, language: language)
            if result.count == 0 || language != defaultLanguage {
                result.append(contentsOf: session.fetch(images: seriesID, type: type, language: defaultLanguage))
            }
            return result
        }()

        for image in images {
            guard let fileURL = URL(string: TheTVDB.bannerPath + image.fileName),
                let thumbURL = URL(string: TheTVDB.bannerPath + image.fileName.replacingOccurrences(of: ".jpg", with: "_t.jpg"))
                else { continue }

            var selected = true

            if type == .season, let subKey = image.subKey, subKey != season {
                selected = false
            }

            if selected {
                artworks.append(Artwork(url: fileURL, thumbURL: image.thumbnail.isEmpty ? fileURL : thumbURL, service: self.name, type: type, size: .standard))
            }
        }
        return artworks
    }

    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        guard let id = metadata[.serviceEpisodeID] as? Int else { return metadata }
        guard let seriesId = metadata[.serviceContentID] as? Int else { return metadata }

        var artworks: [Artwork] = []

        if let info = session.fetch(episodeInfo: id, language: language) {
            metadata[.director]       = cleanList(names: info.directors)
            metadata[.screenwriters]  = cleanList(names: info.writers)

            let guests = cleanList(names: info.guestStars)
            if let actors = metadata[.cast] as? String {
                if actors.count > 0 && guests.count > 0 {
                    metadata[.cast] = actors + ", " + guests
                }
            } else if guests.count > 0 {
                metadata[.cast] = guests
            }

            if let filename = info.filename, let url = URL(string: TheTVDB.bannerPath + filename) {
                artworks.append(Artwork(url: url, thumbURL: url, service: self.name, type: .episode, size: .rectangle))
            }
        }

        // Get additionals images
        if let season = metadata[.season] as? Int {
            var iTunesImage = [Artwork](), appleTV = [Artwork](), squareTVArt = [Artwork](), seasonImages = [Artwork](), posterImages = [Artwork]()
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
            DispatchQueue.global().async(group: group) {
                seasonImages = self.loadTVArtwork(seriesID: seriesId, type: .season, season: String(season), language: language)
            }
            DispatchQueue.global().async(group: group) {
                posterImages = self.loadTVArtwork(seriesID: seriesId, type: .poster, season: String(season), language: language)
            }
            group.wait()

            artworks.insert(contentsOf: iTunesImage, at: 0)
            artworks.insert(contentsOf: squareTVArt, at: 0)
            artworks.insert(contentsOf: appleTV, at: 0)
            artworks.append(contentsOf: seasonImages)
            artworks.append(contentsOf: posterImages)
        }

        metadata.remoteArtworks = artworks

        return metadata
    }

    // MARK: - Unimplemented movie search

    public func search(movie: String, language: String) -> [MetadataResult] {
        return []
    }

    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        return metadata
    }
}
