//
//  PluginMetadataService.swift
//  Subler
//
//  Wraps a loaded SublerMetadataPlugin so it behaves exactly like a
//  built-in MetadataService everywhere Subler uses one -- the Search
//  Metadata dialog, the batch queue's provider popup, etc. Translates the
//  plugin's Foundation-only dictionaries (see SublerMetadataPlugin) into
//  Subler's own MetadataResult type and back.
//

import Foundation
import MP42Foundation

public struct PluginMetadataService: MetadataService {

    let plugin: SublerMetadataPlugin

    public var languages: [String] { return ["en"] }
    public var languageType: LanguageType { return .custom }
    public var defaultLanguage: String { return "en" }
    public var name: String { return plugin.pluginName }

    // MARK: - Movie search

    public func search(movie: String, language: String) -> [MetadataResult] {
        return plugin.searchMovie(query: movie).map { metadataResult(from: $0) }
    }

    public func loadMovieMetadata(_ partialMetadata: MetadataResult, language: String) -> MetadataResult {
        guard let id = partialMetadata[.serviceContentID] as? String else { return partialMetadata }
        let dictionary = plugin.loadMovieMetadata(id: id)
        return dictionary.isEmpty ? partialMetadata : metadataResult(from: dictionary)
    }

    /// Maps the documented dictionary keys (see SublerMetadataPlugin) onto
    /// the corresponding MetadataResult fields. Every key is optional --
    /// a plugin only needs to supply what it actually has.
    private func metadataResult(from dictionary: [String: Any]) -> MetadataResult {
        let metadata = MetadataResult()
        metadata.mediaKind = .movie

        metadata[.serviceContentID] = dictionary["id"] as? String
        metadata[.name]             = dictionary["title"] as? String
        metadata[.releaseDate]      = dictionary["releaseDate"] as? String
        metadata[.longDescription]  = dictionary["synopsis"] as? String
        metadata[.studio]           = dictionary["studio"] as? String
        metadata[.director]         = dictionary["director"] as? String
        metadata[.seriesName]       = dictionary["series"] as? String

        if let cast = dictionary["cast"] as? [String], cast.isEmpty == false {
            metadata[.cast] = cast.joined(separator: ", ")
        }
        if let genre = dictionary["genre"] as? [String], genre.isEmpty == false {
            metadata[.genre] = genre.joined(separator: ", ")
        }

        if let artworkURLStrings = dictionary["artworkURLs"] as? [String] {
            metadata.remoteArtworks = artworkURLStrings.compactMap { string -> Artwork? in
                guard let url = URL(string: string) else { return nil }
                return Artwork(url: url, thumbURL: url, service: name, type: .poster, size: .standard)
            }
        }

        return metadata
    }

    // MARK: - TV Show (not supported by plugins yet)

    public func search(tvShow: String, language: String) -> [String] {
        return []
    }

    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        return []
    }

    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        return metadata
    }
}
