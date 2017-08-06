//
//  TheMovieDB.swift
//  Subler
//
//  Created by Damiano Galassi on 27/06/2017.
//

import Foundation

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

    private func metadata(forMoviePartialResult result: TMDBMovieSearchResult, language: String?) -> SBMetadataResult {
        let metadata = SBMetadataResult()

        metadata.mediaKind = 9; // movie

        metadata["TheMovieDB ID"]                 = result.id
        metadata[SBMetadataResultName]            = result.title
        metadata[SBMetadataResultReleaseDate]     = result.release_date
        metadata[SBMetadataResultDescription]     = result.overview
        metadata[SBMetadataResultLongDescription] = result.overview;

        return metadata
    }

    public func search(movie: String, language: String) -> [SBMetadataResult] {
        let results = session.search(movie: movie, language: language)
        return results.map { metadata(forMoviePartialResult: $0, language: nil) }
    }

    // MARK: - Helpers
    
    private func cleanList(items: [TMDBTuple]?) -> String? {
        guard let items = items else { return nil }
        if items.count == 0 { return nil }
        return items.flatMap { (t: TMDBTuple) -> String? in return t.name }
            .reduce("", { (s1: String, s2: String) -> String in return s1 + (s1.count > 0 ? ", " : "") + s2 })
    }
    
    private func cleanList(cast: [TMDBCast]?) -> String? {
        guard let cast = cast else { return nil }
        if cast.count == 0 { return nil }
        return cast.flatMap { (t: TMDBCast) -> String? in return t.name }
            .reduce("", { (s1: String, s2: String) -> String in return s1 + (s1.count > 0 ? ", " : "") + s2 })
    }
    
    private func cleanList(crew: [TMDBCrew]?, job: String ) -> String? {
        guard let crew = crew else { return nil }
        let found = crew.filter { (c: TMDBCrew) -> Bool in return c.job == job }
        if found.count == 0 { return nil }
        return found.flatMap { $0.name }
            .reduce("", { $0 + ($0.count > 0 ? ", " : "") + $1 })
    }
    
    private func cleanList(crew: [TMDBCrew]?, department: String ) -> String? {
        guard let crew = crew else { return nil }
        let found = crew.filter { (c: TMDBCrew) -> Bool in return c.department == department }
        if found.count == 0 { return nil }
        return found.flatMap { $0.name }
            .reduce("", { $0 + ($0.count > 0 ? ", " : "") + $1 })
    }

    // MARK: - Movie metadata loading

    private func loadArtwork(filePath: String, baseURL: String, thumbSize: String, kind: String) -> RemoteImage? {
        guard let url = URL(string: baseURL + "original" + filePath),
            let thumbURL = URL(string: baseURL + thumbSize + filePath) else { return nil }
        return RemoteImage(url: url, thumbURL: thumbURL, service: self.name, type: kind)
    }

    private func loadMovieArtworks(result: TMDBMovie) -> [RemoteImage] {
        var artworks: [RemoteImage] = Array()

        // add iTunes artwork
        if let title = result.title, let iTunesMetadata = iTunesStore.quickiTunesSearch(movieName: title),
            let iTunesArtwork = iTunesMetadata.remoteArtworks {
            artworks.append(contentsOf: iTunesArtwork.toStruct())
        }

        // Add TheMovieDB artworks
        if let config = session.fetchConfiguration()?.images,
            let imageBaseURL = config.secure_base_url,
            let posterThumbnailSize = config.poster_sizes.first,
            let backdropThumbnailSize = config.backdrop_sizes.first {

            if let images = result.images?.posters {
                artworks.append(contentsOf: images.flatMap { loadArtwork(filePath: $0.file_path, baseURL: imageBaseURL, thumbSize: posterThumbnailSize, kind: "poster") } )
            }

            if result.images?.posters?.count == 0, let posterPath = result.poster_path,
                let artwork = loadArtwork(filePath: posterPath, baseURL: imageBaseURL, thumbSize: posterThumbnailSize, kind: "poster") {
                artworks.append(artwork)
            }

            if let backdropPath = result.backdrop_path,
                let artwork = loadArtwork(filePath: backdropPath, baseURL: imageBaseURL, thumbSize: backdropThumbnailSize, kind: "poster") {
                artworks.append(artwork)
            }
        }

        return artworks
    }

    private func metadata(forResult result: TMDBMovie, language: String?) -> SBMetadataResult {
        let metadata = SBMetadataResult()
        
        metadata.mediaKind = 9; // movie
        
        metadata[SBMetadataResultName]            = result.title
        metadata[SBMetadataResultReleaseDate]     = result.release_date
        metadata[SBMetadataResultDescription]     = result.overview
        metadata[SBMetadataResultLongDescription] = result.overview

        metadata[SBMetadataResultGenre]             = cleanList(items: result.genres)
        metadata[SBMetadataResultStudio]            = cleanList(items: result.production_companies)
        metadata[SBMetadataResultCast]              = cleanList(cast: result.casts?.cast)
        metadata[SBMetadataResultDirector]          = cleanList(crew: result.casts?.crew, job: "Director")
        metadata[SBMetadataResultProducers]         = cleanList(crew: result.casts?.crew, job: "Producer")
        metadata[SBMetadataResultExecutiveProducer] = cleanList(crew: result.casts?.crew, job: "Executive Producer")
        metadata[SBMetadataResultScreenwriters]     = cleanList(crew: result.casts?.crew, department: "Writing")
        metadata[SBMetadataResultComposer]          = cleanList(crew: result.casts?.crew, job: "Original Music Composer")

        if let releases = result.releases {
            for release in releases.countries {
                if release.iso_3166_1 == "US" {
                    metadata[SBMetadataResultRating] = MP42Ratings.defaultManager.ratingStringForiTunesCountry("USA",
                                                                                                               media: "movie",
                                                                                                               ratingString: release.certification)
                }
            }
        }

        metadata.remoteArtworks = loadMovieArtworks(result: result).toClass()

        return metadata
    }

    public func loadMovieMetadata(_ partialMetadata: SBMetadataResult, language: String) -> SBMetadataResult {
        guard let movieID = partialMetadata["TheMovieDB ID"] as? Int,
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

    private func loadTVShowArtworks(result: TMDBSeries) -> [RemoteImage] {
        var artworks: [RemoteImage] = Array()

        // Add TheMovieDB artworks
        if let config = session.fetchConfiguration()?.images,
            let imageBaseURL = config.secure_base_url,
            let posterThumbnailSize = config.poster_sizes.first,
            let backdropThumbnailSize = config.backdrop_sizes.first {

            if let images = result.images?.posters {
                for image in images {
                    if let url = URL(string: imageBaseURL + "original" + image.file_path),
                        let thumbURL = URL(string: imageBaseURL + posterThumbnailSize + image.file_path) {
                        let remoteImage = RemoteImage(url: url, thumbURL: thumbURL, service: self.name, type: "poster")
                        artworks.append(remoteImage)
                    }
                }
            }

            if result.images?.posters?.count == 0,
                let posterPath = result.poster_path,
                let url = URL(string: imageBaseURL + "original" + posterPath),
                let thumbURL = URL(string: imageBaseURL + posterThumbnailSize + posterPath) {
                let remoteImage = RemoteImage(url: url, thumbURL: thumbURL, service: self.name, type: "poster")
                artworks.append(remoteImage)
            }

            if let backdropPath = result.backdrop_path,
                let url = URL(string: imageBaseURL + "original" + backdropPath),
                let thumbURL = URL(string: imageBaseURL + backdropThumbnailSize + backdropPath) {
                let remoteImage = RemoteImage(url: url, thumbURL: thumbURL, service: self.name, type: "poster")
                artworks.append(remoteImage)
            }
        }

        return artworks
    }

    private func metadata(forTVResult result: TMDBEpisode, info: TMDBSeries) -> SBMetadataResult {
        let metadata = SBMetadataResult()

        metadata.mediaKind = 10; // tv

        // TV Show Info
        metadata["TheMovieDB Series ID"]             = info.id
        metadata[SBMetadataResultSeriesName]         = info.name
        metadata[SBMetadataResultSeriesDescription]  = info.overview
        metadata[SBMetadataResultGenre]              = cleanList(items: info.genres)
        metadata[SBMetadataResultNetwork]            = cleanList(items: info.networks)

        // Episode Info
        metadata["TheMovieDB Episodes ID"]          = result.id
        metadata[SBMetadataResultName]              = result.name
        metadata[SBMetadataResultReleaseDate]       = result.air_date
        metadata[SBMetadataResultDescription]       = result.overview
        metadata[SBMetadataResultLongDescription]   = result.overview;

        metadata[SBMetadataResultSeason]            = result.season_number
        metadata[SBMetadataResultEpisodeID]         = String(format: "%d%02d", result.season_number ?? 0, result.episode_number ?? 0)
        metadata[SBMetadataResultEpisodeNumber]     = result.episode_number
        metadata[SBMetadataResultTrackNumber]       = result.episode_number

        let cast = cleanList(cast: info.credits?.cast)
        let guests = cleanList(cast: result.guest_stars)
        if let cast = cast, let guests = guests {
            metadata[SBMetadataResultCast] = cast + ", " + guests
        }
        else if let cast = cast {
            metadata[SBMetadataResultCast] = cast
        }
        else if let guests = guests {
            metadata[SBMetadataResultCast] = guests
        }

        metadata[SBMetadataResultStudio]            = cleanList(items: info.production_companies)
        metadata[SBMetadataResultDirector]          = cleanList(crew: result.crew, job: "Director")
        metadata[SBMetadataResultProducers]         = cleanList(crew: result.crew, job: "Producer")
        metadata[SBMetadataResultExecutiveProducer] = cleanList(crew: result.crew, job: "Executive Producer")
        metadata[SBMetadataResultScreenwriters]     = cleanList(crew: result.crew, department: "Writing")
        metadata[SBMetadataResultComposer]          = cleanList(crew: result.crew, job: "Original Music Composer")

        if let ratings = info.content_ratings?.results {
            let USRating = ratings.filter { $0.iso_3166_1 == "US" }.flatMap { $0.rating }
            if let rating = USRating.first {
                metadata[SBMetadataResultRating] = MP42Ratings.defaultManager.ratingStringForiTunesCountry("USA",
                                                                                                           media: "TV",
                                                                                                           ratingString: rating)
            }
        }

        metadata.remoteArtworks = loadTVShowArtworks(result: info).toClass()

        return metadata
    }

    private func loadEpisodes(seriesID: Int, info: TMDBSeries, season: Int?, episode: Int?, language: String) -> [SBMetadataResult] {
        let episodes = session.fetch(episodeForSeriesID: seriesID, season: season, episode: episode, language: language)

        let filteredEpisodes = episodes.filter {
            (season != nil ? ($0.season_number ?? 0) == season : true) &&
            (episode != nil ? ($0.episode_number ?? 0) == episode : true)
        }

        return filteredEpisodes.map { metadata(forTVResult: $0, info: info) }
    }

    public func search(TVSeries: String, language: String, season: Int?, episode: Int?) -> [SBMetadataResult] {
        let seriesIDs: [Int] =  {
            let result = self.searchIDs(seriesName: TVSeries, language: language)
            return result.count > 0 ? result : self.searchIDs(seriesName: TVSeries, language: defaultLanguage)
        }()

        var results: [SBMetadataResult] = Array()

        for id in seriesIDs {
            guard let info = session.fetch(seriesID: id, language: language) else { continue }
            let episodes = loadEpisodes(seriesID: id, info: info, season: season, episode: episode, language: language)
            results.append(contentsOf: episodes)
        }

        return results
    }

    public func loadTVMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult {
        var artworks: [RemoteImage] = Array()

        if let seriesID = metadata["TheMovieDB Series ID"] as? Int, let episodeID = metadata["TheMovieDB Episodes ID"] as? Int,
            let season = metadata[SBMetadataResultSeason] as? Int {

            let seasonImages = session.fetch(imagesForSeriesID: seriesID, season: String(season), language: language)
            let episodeImages = session.fetch(imagesForSeriesID: seriesID, episodeID: episodeID, season: String(season), language: language)

            if let config = session.fetchConfiguration()?.images,
                let imageBaseURL = config.secure_base_url,
                let posterThumbnailSize = config.poster_sizes.first {

                artworks.append(contentsOf: seasonImages.flatMap { loadArtwork(filePath: $0.file_path, baseURL: imageBaseURL, thumbSize: posterThumbnailSize, kind: "season") } )
                artworks.append(contentsOf: episodeImages.flatMap { loadArtwork(filePath: $0.file_path, baseURL: imageBaseURL, thumbSize: posterThumbnailSize, kind: "episode") } )
            }
        }

        if let existingArtworks = metadata.remoteArtworks {
            artworks.append(contentsOf: existingArtworks.toStruct())
        }

        metadata.remoteArtworks = artworks.toClass()

        return metadata
    }
}
