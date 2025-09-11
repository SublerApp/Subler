//
//  TheMovieDB.swift
//  Subler
//
//  Created by Damiano Galassi on 27/06/2017.
//

import Foundation
import MP42Foundation

public struct TheMovieDB: MetadataService {

    private let session = TheMovieDBService.sharedInstance

    public var languages: [String] {
        get {
            return MP42Languages.defaultManager.iso_639_1Languages
        }
    }

    public var languageType: LanguageType {
        get {
            return .ISO
        }
    }

    public var defaultLanguage: String {
        return "en"
    }

    public var name: String {
        return "TheMovieDB"
    }

    // MARK: - Movie Search

    private func metadata(forMoviePartialResult result: TMDBMovieSearchResult, language: String?) -> MetadataResult {
        let metadata = MetadataResult()

        metadata.mediaKind = .movie

        metadata[.serviceContentID] = result.id
        metadata[.name]            = result.title
        metadata[.releaseDate]     = result.release_date
        metadata[.longDescription] = result.overview;

        return metadata
    }

    public func search(movie: String, language: String) -> [MetadataResult] {
        let results = session.search(movie: movie, language: language)
        return results.map { metadata(forMoviePartialResult: $0, language: nil) }
    }

    // MARK: - Helpers
    
    private func cleanList(items: [TMDBTuple]?) -> String? {
        guard let items = items else { return nil }
        if items.count == 0 { return nil }
        return items.compactMap { (t: TMDBTuple) -> String? in return t.name }
            .reduce("", { (s1: String, s2: String) -> String in return s1 + (s1.isEmpty ? "" : ", ") + s2 })
    }
    
    private func cleanList(cast: [TMDBCast]?) -> String? {
        guard let cast = cast else { return nil }
        if cast.count == 0 { return nil }
        return cast.compactMap { (t: TMDBCast) -> String? in return t.name }
            .reduce("", { (s1: String, s2: String) -> String in return s1 + (s1.isEmpty ? "" : ", ") + s2 })
    }
    
    private func cleanList(crew: [TMDBCrew]?, job: String ) -> String? {
        guard let crew = crew else { return nil }
        let found = crew.filter { (c: TMDBCrew) -> Bool in return c.job == job }
        if found.count == 0 { return nil }
        return found.compactMap { $0.name }
            .reduce("", { $0 + ($0.isEmpty ? "" : ", " ) + $1 })
    }
    
    private func cleanList(crew: [TMDBCrew]?, department: String ) -> String? {
        guard let crew = crew else { return nil }
        let found = crew.filter { (c: TMDBCrew) -> Bool in return c.department == department }
        if found.count == 0 { return nil }
        return found.compactMap { $0.name }
            .reduce("", { $0 + ($0.isEmpty ? "" : ", ") + $1 })
    }

    // MARK: - TV Series name search

    public func search(tvShow: String, language: String) -> [String] {
        var results: Set<String> = Set()

        let series = session.search(series: tvShow, language: language)
        results.formUnion(series.compactMap { $0.name } )

        if language != defaultLanguage {
            let englishResults = search(tvShow: tvShow, language: defaultLanguage)
            results.formUnion(englishResults)
        }

        return Array(results)
    }

    // MARK: - Movie metadata loading

    private func loadArtwork(filePath: String, baseURL: String, thumbSize: String, kind: ArtworkType) -> Artwork? {
        guard let url = URL(string: baseURL + "original" + filePath),
            let thumbURL = URL(string: baseURL + thumbSize + filePath) else { return nil }
        return Artwork(url: url, thumbURL: thumbURL, service: self.name, type: kind, size: .standard)
    }

    private func loadMovieArtworks(result: TMDBMovie) -> [Artwork] {
        var artworks: [Artwork] = []

        var iTunesImage = [Artwork](), appleTV = [Artwork]()
        let group = DispatchGroup()

        DispatchQueue.global().async(group: group) {
            // add iTunes artwork
            if let title = result.title, let iTunesMetadata = iTunesStore.quickiTunesSearch(movieName: title) {
                iTunesImage = iTunesMetadata.remoteArtworks
            }
        }

        DispatchQueue.global().async(group: group) {
           if let title = result.title,
                let store = iTunesStore.Store(language: "USA (English)") {
                appleTV = AppleTV().searchArtwork(term: title, store: store, type: .movie)
            }
        }
        group.wait()

        artworks.append(contentsOf: appleTV)
        artworks.append(contentsOf: iTunesImage)

        // Add TheMovieDB artworks
        if let config = session.fetchConfiguration()?.images,
            let imageBaseURL = config.secure_base_url,
            let posterThumbnailSize = config.poster_sizes.first,
            let backdropThumbnailSize = config.backdrop_sizes.first {

            if let backdropPath = result.backdrop_path,
                let artwork = loadArtwork(filePath: backdropPath, baseURL: imageBaseURL, thumbSize: backdropThumbnailSize, kind: .backdrop) {
                artworks.append(artwork)
            }

            if let images = result.images?.posters {
                artworks.append(contentsOf: images.compactMap { loadArtwork(filePath: $0.file_path, baseURL: imageBaseURL, thumbSize: posterThumbnailSize, kind: .poster) } )
            }

            if result.images?.posters?.count == 0, let posterPath = result.poster_path,
                let artwork = loadArtwork(filePath: posterPath, baseURL: imageBaseURL, thumbSize: posterThumbnailSize, kind: .poster) {
                artworks.append(artwork)
            }

        }

        return artworks
    }

    private func metadata(forResult result: TMDBMovie, language: String?) -> MetadataResult {
        let metadata = MetadataResult()
        
        metadata.mediaKind = .movie
        
        metadata[.name]            = result.title
        metadata[.releaseDate]     = result.release_date
        metadata[.longDescription] = result.overview

        metadata[.genre]             = cleanList(items: result.genres)
        metadata[.studio]            = cleanList(items: result.production_companies)
        metadata[.cast]              = cleanList(cast: result.casts?.cast)
        metadata[.director]          = cleanList(crew: result.casts?.crew, job: "Director")
        metadata[.producers]         = cleanList(crew: result.casts?.crew, job: "Producer")
        metadata[.executiveProducer] = cleanList(crew: result.casts?.crew, job: "Executive Producer")
        metadata[.screenwriters]     = cleanList(crew: result.casts?.crew, department: "Writing")
        metadata[.composer]          = cleanList(crew: result.casts?.crew, job: "Original Music Composer")

        if let releases = result.releases {
            for release in releases.countries {
                if release.iso_3166_1 == "US" {
                    metadata[.rating] = Ratings.shared.rating(countryCode: "USA", mediaKind: .movie, name: release.certification)?.iTunesCode
                }
            }
        }

        metadata.remoteArtworks = loadMovieArtworks(result: result)
        metadata[.serviceContentID] = result.id

        return metadata
    }

    public func loadMovieMetadata(_ partialMetadata: MetadataResult, language: String) -> MetadataResult {
        guard let movieID = partialMetadata[.serviceContentID] as? Int,
              let result = session.fetch(movieID: movieID, language: language)
            else { return partialMetadata }

        return metadata(forResult: result, language: language)
    }

    // MARK: - TV Search

    private func match(series: TMDBTVSearchResult, name: String) -> Bool {
        if series.name?.caseInsensitiveCompare(name) == .orderedSame  {
            return true
        }

        if series.original_name?.caseInsensitiveCompare(name) == .orderedSame  {
            return true
        }

        return false
    }

    private func searchIDs(seriesName: String, language: String) -> [Int] {
        let series = session.search(series: seriesName, language: language)
        let filteredSeries = series.filter { match(series: $0, name: seriesName) }.map { $0.id }

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

    private func loadSquareTVArtwork(_ metadata: MetadataResult) -> [Artwork] {
        guard let tvShow = metadata[.seriesName] as? String,
            let seasonNum = metadata[.season] as? Int,
            let seriesId = metadata[.serviceAdditionalContentID] as? Int
            else { return [] }

        return SquaredTVArt().search(tvShow: tvShow, theTVDBSeriesId: seriesId, season: seasonNum)
    }

    private func loadTVShowArtworks(result: TMDBSeries) -> [Artwork] {
        var artworks: [Artwork] = []

        // Add TheMovieDB artworks
        if let config = session.fetchConfiguration()?.images,
            let imageBaseURL = config.secure_base_url,
            let posterThumbnailSize = config.poster_sizes.first,
            let backdropThumbnailSize = config.backdrop_sizes.first {

            if let backdropPath = result.backdrop_path,
                let url = URL(string: imageBaseURL + "original" + backdropPath),
                let thumbURL = URL(string: imageBaseURL + backdropThumbnailSize + backdropPath) {
                let remoteImage = Artwork(url: url, thumbURL: thumbURL, service: self.name, type: .backdrop, size: .rectangle)
                artworks.append(remoteImage)
            }

            if let images = result.images?.posters {
                for image in images {
                    if let url = URL(string: imageBaseURL + "original" + image.file_path),
                        let thumbURL = URL(string: imageBaseURL + posterThumbnailSize + image.file_path) {
                        let remoteImage = Artwork(url: url, thumbURL: thumbURL, service: self.name, type: .poster, size: .standard)
                        artworks.append(remoteImage)
                    }
                }
            }

            if result.images?.posters?.count == 0,
                let posterPath = result.poster_path,
                let url = URL(string: imageBaseURL + "original" + posterPath),
                let thumbURL = URL(string: imageBaseURL + posterThumbnailSize + posterPath) {
                let remoteImage = Artwork(url: url, thumbURL: thumbURL, service: self.name, type: .poster, size: .standard)
                artworks.append(remoteImage)
            }

        }

        return artworks
    }

    private func metadata(forTVResult result: TMDBEpisode, info: TMDBSeries) -> MetadataResult {
        let metadata = MetadataResult()

        metadata.mediaKind = .tvShow

        // TV Show Info
        metadata[.serviceContentID]           = info.id
        metadata[.serviceAdditionalContentID] = info.external_ids?.tvdb_id

        metadata[.seriesName]         = info.name
        metadata[.seriesDescription]  = info.overview
        metadata[.genre]              = cleanList(items: info.genres)
        metadata[.network]            = cleanList(items: info.networks)

        // Episode Info
        metadata[.serviceEpisodeID]  = result.id
        metadata[.name]              = result.name
        metadata[.releaseDate]       = result.air_date
        metadata[.longDescription]   = result.overview;

        metadata[.season]            = result.season_number
        metadata[.episodeID]         = String(format: "%d%02d", result.season_number ?? 0, result.episode_number ?? 0)
        metadata[.episodeNumber]     = result.episode_number
        metadata[.trackNumber]       = result.episode_number

        let cast = cleanList(cast: info.credits?.cast)
        let guests = cleanList(cast: result.guest_stars)
        if let cast = cast, let guests = guests {
            metadata[.cast] = cast + ", " + guests
        }
        else if let cast = cast {
            metadata[.cast] = cast
        }
        else if let guests = guests {
            metadata[.cast] = guests
        }

        metadata[.studio]            = cleanList(items: info.production_companies)
        metadata[.director]          = cleanList(crew: result.crew, job: "Director")
        metadata[.producers]         = cleanList(crew: result.crew, job: "Producer")
        metadata[.executiveProducer] = cleanList(crew: result.crew, job: "Executive Producer")
        metadata[.screenwriters]     = cleanList(crew: result.crew, department: "Writing")
        metadata[.composer]          = cleanList(crew: result.crew, job: "Original Music Composer")

        if let ratings = info.content_ratings?.results {
            let USRating = ratings.filter { $0.iso_3166_1 == "US" }.compactMap { $0.rating }
            if let rating = USRating.first {
                metadata[.rating] = Ratings.shared.rating(countryCode: "USA", mediaKind: .tvShow, name: rating)?.iTunesCode
            }
        }

        metadata.remoteArtworks = loadTVShowArtworks(result: info)

        return metadata
    }

    private func loadEpisodes(seriesID: Int, info: TMDBSeries, season: Int?, episode: Int?, language: String) -> [MetadataResult] {
        let episodes = session.fetch(episodeForSeriesID: seriesID, season: season, episode: episode, language: language)

        let filteredEpisodes = episodes.filter {
            (season != nil ? ($0.season_number ?? 0) == season : true) &&
            (episode != nil ? ($0.episode_number ?? 0) == episode : true)
        }

        return filteredEpisodes.map { metadata(forTVResult: $0, info: info) }
    }

    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        let seriesIDs: [Int] =  {
            let result = self.searchIDs(seriesName: tvShow, language: language)
            return result.isEmpty ? self.searchIDs(seriesName: tvShow, language: defaultLanguage) : result
        }()

        var results: [MetadataResult] = []

        for id in seriesIDs {
            guard let info = session.fetch(seriesID: id, language: language) else { continue }
            let episodes = loadEpisodes(seriesID: id, info: info, season: season, episode: episode, language: language)
            results.append(contentsOf: episodes)
        }

        return results
    }

    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        var artworks: [Artwork] = []

        if let seriesID = metadata[.serviceContentID] as? Int, let season = metadata[.season] as? Int,
            let episodeNumber = metadata[.episodeNumber] as? Int {

            let seasonImages = session.fetch(imagesForSeriesID: seriesID, season: String(season), language: language)
            let episodeImages = session.fetch(imagesForSeriesID: seriesID, episodeNumber: episodeNumber, season: String(season), language: language)

            if let config = session.fetchConfiguration()?.images,
                let imageBaseURL = config.secure_base_url,
                let posterThumbnailSize = config.poster_sizes.first {

                artworks.append(contentsOf: seasonImages.compactMap { loadArtwork(filePath: $0.file_path, baseURL: imageBaseURL, thumbSize: posterThumbnailSize, kind: .season) } )
                artworks.append(contentsOf: episodeImages.compactMap { loadArtwork(filePath: $0.file_path, baseURL: imageBaseURL, thumbSize: posterThumbnailSize, kind: .episode) } )
            }

        }

        artworks.insert(contentsOf: metadata.remoteArtworks, at: 0)

        var iTunesImage = [Artwork](), appleTV = [Artwork](), squareTVArt = [Artwork]()
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) {
            // add iTunes artwork
            if let name = metadata[.seriesName] as? String,
                let iTunesMetadata = iTunesStore.quickiTunesSearch(tvSeriesName: name,
                                                                   seasonNum: metadata[.season] as? Int,
                                                                   episodeNum: metadata[.episodeNumber] as? Int) {
                iTunesImage = iTunesMetadata.remoteArtworks
            }
        }
        DispatchQueue.global().async(group: group) {
            if let name = metadata[.seriesName] as? String,
                let season = metadata[.season] as? Int,
                let store = iTunesStore.Store(language: "USA (English)") {

                appleTV = AppleTV().searchArtwork(term: name, store: store, type: .tvShow(season: season))
            }
        }
        DispatchQueue.global().async(group: group) {
            // Add Squared TV Artwork
            squareTVArt = self.loadSquareTVArtwork(metadata)
        }
        group.wait()

        artworks.insert(contentsOf: iTunesImage, at: 0)
        artworks.insert(contentsOf: squareTVArt, at: 0)
        artworks.insert(contentsOf: appleTV, at: 0)

        metadata.remoteArtworks = artworks

        return metadata
    }
}
