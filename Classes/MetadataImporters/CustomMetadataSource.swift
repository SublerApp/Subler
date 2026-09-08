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

public extension MetadataResult.Key {
    /// The starter set of fields a newly-added custom source shows for
    /// mapping -- the "common" subset of MetadataResult.Key that makes
    /// sense coming from an arbitrary JSON API. A source can add more (or
    /// remove some of these) via the Preferences pane's "+"/"-" buttons
    /// afterwards -- this is only the default, not a ceiling.
    static var customSourceDefaultFields: [MetadataResult.Key] {
        return [.name, .genre, .releaseDate, .description, .longDescription,
                .rating, .studio, .cast, .director, .producers,
                .screenwriters, .executiveProducer, .copyright, .seriesDescription]
    }

    /// Every field the "+" picker in Preferences > Sources offers, whether
    /// or not it's already part of a given source's mapping. Deliberately
    /// still short of the *full* MetadataResult.Key list -- iTunes- and
    /// TV-service-internal bookkeeping keys (contentID, playlistID,
    /// serviceEpisodeID, and the like) aren't something a JSON API a user
    /// configures by hand could sensibly fill in. contentRating is also
    /// excluded: the real content-rating MP4 atom comes from
    /// MetadataResult.contentRating (a separate Int property, same as
    /// mediaKind), never from this string-keyed dictionary, so mapping it
    /// here wouldn't do anything -- and it has no localizedKeys entry, so
    /// it would show up as literally "Null" in the picker.
    static var customSourceAllMappableKeys: [MetadataResult.Key] {
        return customSourceDefaultFields + [.composer, .seriesName, .network, .season,
                                             .episodeNumber, .episodeID, .trackNumber,
                                             .diskNumber]
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

    /// Which MetadataResult.Key fields this source currently shows a
    /// mapping row for, and in what order -- the Preferences pane's "+"
    /// and "-" buttons add to and remove from this list. Kept separate
    /// from fieldMappings so a field can be added to the list (and shown,
    /// empty, ready to fill in) before it has a JSON path, and so removing
    /// a row is unambiguous even when its path was already blank.
    public var visibleFields: [MetadataResult.Key]

    public init(name: String = "",
                mediaTypes: Set<CustomSourceMediaType> = [.movie],
                searchURLTemplate: String = "",
                resultsPath: String = "",
                authentication: CustomSourceAuthentication = .none,
                apiKey: String = "",
                fieldMappings: [CustomSourceFieldMapping] = [],
                artworkPath: String = "",
                visibleFields: [MetadataResult.Key] = MetadataResult.Key.customSourceDefaultFields) {
        self.name = name
        self.mediaTypes = mediaTypes
        self.searchURLTemplate = searchURLTemplate
        self.resultsPath = resultsPath
        self.authentication = authentication
        self.apiKey = apiKey
        self.fieldMappings = fieldMappings
        self.artworkPath = artworkPath
        self.visibleFields = visibleFields
    }

    private enum CodingKeys: String, CodingKey {
        case name, mediaTypes, searchURLTemplate, resultsPath, authentication, apiKey, fieldMappings, artworkPath, visibleFields
    }

    /// Custom only so a source saved before visibleFields existed decodes
    /// with a sensible default instead of failing to load at all -- every
    /// other property is still decoded plainly, and encode(to:) is left
    /// for Swift to synthesize from the CodingKeys above.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        mediaTypes = try container.decode(Set<CustomSourceMediaType>.self, forKey: .mediaTypes)
        searchURLTemplate = try container.decode(String.self, forKey: .searchURLTemplate)
        resultsPath = try container.decode(String.self, forKey: .resultsPath)
        authentication = try container.decode(CustomSourceAuthentication.self, forKey: .authentication)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        fieldMappings = try container.decode([CustomSourceFieldMapping].self, forKey: .fieldMappings)
        artworkPath = try container.decode(String.self, forKey: .artworkPath)

        let mappedKeys = fieldMappings.map { $0.field }
        if let savedVisibleFields = try container.decodeIfPresent([MetadataResult.Key].self, forKey: .visibleFields) {
            // Still show a field with a saved mapping even if it somehow
            // isn't in the saved visibleFields list -- a mapping the user
            // already filled in should never just disappear from view.
            visibleFields = savedVisibleFields + mappedKeys.filter { savedVisibleFields.contains($0) == false }
        } else {
            // Pre-existing source saved before this property existed: show
            // every field it already has a mapping for, plus the original
            // starter set, so nothing already configured drops out of view.
            let defaults = MetadataResult.Key.customSourceDefaultFields
            visibleFields = defaults + mappedKeys.filter { defaults.contains($0) == false }
        }
    }
}
