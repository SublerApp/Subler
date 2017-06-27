//
//  TheMovieDB.swift
//  Subler
//
//  Created by Damiano Galassi on 27/06/2017.
//

import Foundation

final public class TheMovieDB: SBMetadataImporter {

    private let session = TheMovieDBService.sharedInstance

    override public var languages: [String] {
        get {
            return MP42Languages.defaultManager.iso_639_1Languages
        }
    }

    override public var languageType: SBMetadataImporterLanguageType {
        get {
            return .ISO
        }
    }

    // MARK: - Search

    private func metadata(forPartialResult result: TMDBSearchResult, language: String?) -> SBMetadataResult {
        let metadata = SBMetadataResult()

        metadata.mediaKind = 9; // movie

        metadata["TheMovieDB ID"]                 = result.id
        metadata[SBMetadataResultName]            = result.title
        metadata[SBMetadataResultReleaseDate]     = result.release_date
        metadata[SBMetadataResultDescription]     = result.overview
        metadata[SBMetadataResultLongDescription] = result.overview;

        return metadata
    }

    override public func searchMovie(_ title: String, language: String) -> [SBMetadataResult] {
        let results = session.search(movie: title, language: language)
        return results.map { metadata(forPartialResult: $0, language: nil) }
    }

    // MARK: - Helpers
    
    private func cleanList(items: [TMDBTuple]) -> String {
        return items.flatMap { $0.name } .reduce("", { $0 + ($0.count > 0 ? ", " : "") + $1 })
    }
    
    private func cleanList(cast: [TMDBCast]) -> String {
        return cast.flatMap { $0.name } .reduce("", { $0 + ($0.count > 0 ? ", " : "") + $1 })
    }
    
    private func cleanList(crew: [TMDBCrew], job: String ) -> String {
        return crew.filter { $0.job == job }.flatMap { $0.name } .reduce("", { $0 + ($0.count > 0 ? ", " : "") + $1 })
    }
    
    private func cleanList(crew: [TMDBCrew], department: String ) -> String {
        return crew.filter { $0.department == department }.flatMap { $0.name } .reduce("", { $0 + ($0.count > 0 ? ", " : "") + $1 })
    }

    // MARK: - Movie metadata loading

    private func loadArtworks(result: TMDBMovie) -> [SBRemoteImage] {
        var artworks: [SBRemoteImage] = Array()

        // add iTunes artwork
        if let title = result.title, let iTunesMetadata = SBiTunesStore.quickiTunesSearchMovie(title),
            let iTunesArtwork = iTunesMetadata.remoteArtworks {
            artworks.append(contentsOf: iTunesArtwork)
        }

        // Add TheMovieDB artworks
        if let config = session.fetchConfiguration()?.images,
            let imageBaseURL = config.secure_base_url,
            let posterThumbnailSize = config.poster_sizes.first,
            let backdropThumbnailSize = config.backdrop_sizes.first {

            if let images = result.images {
                for image in images.posters {
                    if let url = URL(string: imageBaseURL + "original" + image.file_path),
                        let thumbURL = URL(string: imageBaseURL + posterThumbnailSize + image.file_path) {
                        let remoteImage = SBRemoteImage(url: url, thumbURL: thumbURL, providerName: "TheMovieDB|poster")
                        artworks.append(remoteImage)
                    }
                }
            }

            if result.images?.posters.count == 0,
                let posterPath = result.poster_path,
                let url = URL(string: imageBaseURL + "original" + posterPath),
                let thumbURL = URL(string: imageBaseURL + posterThumbnailSize + posterPath) {
                let remoteImage = SBRemoteImage(url: url, thumbURL: thumbURL, providerName: "TheMovieDB|poster")
                artworks.append(remoteImage)
            }

            if let backdropPath = result.backdrop_path,
                let url = URL(string: imageBaseURL + "original" + backdropPath),
                let thumbURL = URL(string: imageBaseURL + backdropThumbnailSize + backdropPath) {
                let remoteImage = SBRemoteImage(url: url, thumbURL: thumbURL, providerName: "TheMovieDB|poster")
                artworks.append(remoteImage)
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

        if let genres = result.genres {
            metadata[SBMetadataResultGenre] = cleanList(items: genres)
        }
        if let production = result.production_companies {
            metadata[SBMetadataResultStudio] = cleanList(items: production)
        }
        if let cast = result.casts?.cast {
            metadata[SBMetadataResultCast] = cleanList(cast: cast)
        }
        if let crew = result.casts?.crew {
            metadata[SBMetadataResultDirector]          = cleanList(crew: crew, job: "Director")
            metadata[SBMetadataResultProducers]         = cleanList(crew: crew, job: "Producer")
            metadata[SBMetadataResultExecutiveProducer] = cleanList(crew: crew, job: "Executive Producer")
            metadata[SBMetadataResultScreenwriters]     = cleanList(crew: crew, department: "Writing")
            metadata[SBMetadataResultComposer]          = cleanList(crew: crew, job: "Original Music Composer")
        }

        if let releases = result.releases {
            for release in releases.countries {
                if release.iso_3166_1 == "US" {
                    metadata[SBMetadataResultRating] = MP42Ratings.defaultManager.ratingStringForiTunesCountry("USA",
                                                                                                               media: "movie",
                                                                                                               ratingString: release.certification)
                }
            }
        }

        metadata.remoteArtworks = loadArtworks(result: result)

        return metadata
    }

    override public func loadMovieMetadata(_ partialMetadata: SBMetadataResult, language: String) -> SBMetadataResult {
        guard let movieID = partialMetadata["TheMovieDB ID"] as? Int,
              let result = session.fetch(movieID: movieID, language: language)
            else { return partialMetadata }

        return metadata(forResult: result, language: language)
    }

}
