//
//  CustomMetadataSource.swift
//  Subler
//

import Foundation

/// MetadataResult.Key already behaves like a plain string enum (it's used
/// as a dictionary key throughout MetadataResult), it just never needed
/// Codable before. A custom source's field mapping needs to save which key
/// a JSON path fills in, so it does now.
extension MetadataResult.Key: Codable {}

/// The media type(s) a custom source is offered for. Kept as its own type,
/// separate from MetadataType, so the list can grow to cover media Subler
/// doesn't search yet -- Audiobooks, or a Descriptive Audio track for
/// accessibility -- without disturbing anything that already works.
public enum CustomSourceMediaType: String, Codable, CaseIterable {
    case movie = "Movie"
    case tvShow = "TV Show"
}

/// How a custom source's API key is attached to each request. Different
/// APIs expect this differently -- a query parameter (the TheMovieDB
/// style) or an HTTP header (common for bearer-token APIs) -- so the
/// source picks which, rather than the app guessing.
public enum CustomSourceAuthentication: Codable, Equatable {
    case none
    case queryParameter(name: String)
    case header(name: String)

    private enum CodingKeys: String, CodingKey {
        case kind, name
    }

    private enum Kind: String, Codable {
        case none, queryParameter, header
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .none:
            self = .none
        case .queryParameter:
            self = .queryParameter(name: try container.decode(String.self, forKey: .name))
        case .header:
            self = .header(name: try container.decode(String.self, forKey: .name))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        case .queryParameter(let name):
            try container.encode(Kind.queryParameter, forKey: .kind)
            try container.encode(name, forKey: .name)
        case .header(let name):
            try container.encode(Kind.header, forKey: .kind)
            try container.encode(name, forKey: .name)
        }
    }

    var parameterName: String {
        switch self {
        case .none: return ""
        case .queryParameter(let name): return name
        case .header(let name): return name
        }
    }
}

/// One row of a source's field-mapping table: which MetadataResult.Key a
/// JSON path's value fills in. See JSONPath.swift for the path syntax.
public struct CustomSourceFieldMapping: Codable, Equatable {
    public var field: MetadataResult.Key
    public var jsonPath: String

    public init(field: MetadataResult.Key, jsonPath: String) {
        self.field = field
        self.jsonPath = jsonPath
    }
}

/// The fields a custom source's mapping table can fill in. Deliberately the
/// "common" subset of MetadataResult.Key -- the annotations that make sense
/// coming from an arbitrary JSON API -- rather than the full list, which
/// also includes iTunes- and TV-service-internal bookkeeping keys.
public extension MetadataResult.Key {
    static var customSourceMappableKeys: [MetadataResult.Key] {
        return [.name, .genre, .releaseDate, .description, .longDescription,
                .rating, .studio, .cast, .director, .producers,
                .screenwriters, .executiveProducer, .copyright, .seriesDescription]
    }
}

/// A user-configured metadata source that Subler talks to generically: a
/// search URL template, where in the JSON response the array of matching
/// results lives, and a field-by-field mapping from each result's JSON
/// down to Subler's own metadata annotations. No source-specific code is
/// needed to add a new one -- unlike Subler's built-in providers, which
/// each have their own Swift file, a custom source is entirely data.
public struct CustomMetadataSource: Codable, Equatable {

    public var name: String

    /// Which of Subler's searches this source is offered for.
    public var mediaTypes: Set<CustomSourceMediaType>

    /// The search request URL, with "{query}" replaced at request time by
    /// the URL-encoded search text. For example:
    /// "https://api.example.com/v1/search?q={query}"
    public var searchURLTemplate: String

    /// The JSON path to the array of candidate results within the search
    /// response (e.g. "results", or "data.items"). Empty means the
    /// response itself is that array.
    public var resultsPath: String

    /// How the API key is attached to each request.
    public var authentication: CustomSourceAuthentication
    public var apiKey: String

    /// Per-field JSON paths, applied to each result item found via
    /// resultsPath.
    public var fieldMappings: [CustomSourceFieldMapping]

    /// JSON path (relative to each result item) to that result's artwork
    /// URL. Optional -- a source without artwork just leaves this empty.
    public var artworkPath: String

    public init(name: String = "",
                mediaTypes: Set<CustomSourceMediaType> = [.movie],
                searchURLTemplate: String = "",
                resultsPath: String = "",
                authentication: CustomSourceAuthentication = .none,
                apiKey: String = "",
                fieldMappings: [CustomSourceFieldMapping] = [],
                artworkPath: String = "") {
        self.name = name
        self.mediaTypes = mediaTypes
        self.searchURLTemplate = searchURLTemplate
        self.resultsPath = resultsPath
        self.authentication = authentication
        self.apiKey = apiKey
        self.fieldMappings = fieldMappings
        self.artworkPath = artworkPath
    }
}
