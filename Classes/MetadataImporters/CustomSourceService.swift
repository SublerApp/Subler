//
//  CustomSourceService.swift
//  Subler
//

import Foundation

/// A MetadataService backed entirely by a user-configured CustomMetadataSource
/// rather than by source-specific Swift code. Every custom source -- whatever
/// API it talks to -- runs through this same implementation: build the
/// search URL from the source's template, attach the API key the way the
/// source says to, run the request, then walk the JSON response using the
/// source's field mappings (see JSONPath.swift) to build MetadataResults.
///
/// This intentionally does not special-case any particular source by name.
/// Adding a new one is a matter of filling in the mapping form in
/// Preferences > Sources, not writing code.
public struct CustomSourceService: MetadataService {

    private let source: CustomMetadataSource

    public init(source: CustomMetadataSource) {
        self.source = source
    }

    // MARK: - MetadataService

    public var languageType: LanguageType { .custom }
    public var languages: [String] { [defaultLanguage] }
    public var defaultLanguage: String { "English" }
    public var name: String { source.name }

    public func search(tvShow: String, language: String) -> [String] {
        return results(forQuery: tvShow, mediaKind: .tvShow).compactMap { $0[.name] as? String }
    }

    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        return results(forQuery: tvShow, mediaKind: .tvShow)
    }

    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        // The search response already carries everything the field mapping
        // knows how to fill in -- there's no separate detail request.
        return metadata
    }

    public func search(movie: String, language: String) -> [MetadataResult] {
        return results(forQuery: movie, mediaKind: .movie)
    }

    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        return metadata
    }

    // MARK: - Request / response handling

    private func results(forQuery query: String, mediaKind: MediaKind) -> [MetadataResult] {
        guard query.isEmpty == false,
              let url = requestURL(forQuery: query),
              let data = URLSession.data(from: url, header: requestHeaders()),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        let items: [Any]
        if source.resultsPath.trimmingCharacters(in: .whitespaces).isEmpty {
            items = json as? [Any] ?? []
        } else {
            items = JSONPath.resolve(source.resultsPath, in: json) as? [Any] ?? []
        }

        return items.map { makeMetadataResult(from: $0, mediaKind: mediaKind) }
    }

    private func requestURL(forQuery query: String) -> URL? {
        var urlString = source.searchURLTemplate.replacingOccurrences(of: "{query}", with: query.urlEncoded())

        if case .queryParameter(let paramName) = source.authentication, paramName.isEmpty == false {
            let separator = urlString.contains("?") ? "&" : "?"
            urlString += "\(separator)\(paramName)=\(source.apiKey.urlEncoded())"
        }

        return URL(string: urlString)
    }

    private func requestHeaders() -> [String: String] {
        if case .header(let headerName) = source.authentication, headerName.isEmpty == false {
            return [headerName: source.apiKey]
        }
        return [:]
    }

    private func makeMetadataResult(from item: Any, mediaKind: MediaKind) -> MetadataResult {
        let result = MetadataResult()
        result.mediaKind = mediaKind

        for mapping in source.fieldMappings {
            if let value = JSONPath.resolveString(mapping.jsonPath, in: item) {
                result[mapping.field] = value
            }
        }

        let artworkPath = source.artworkPath.trimmingCharacters(in: .whitespaces)
        if artworkPath.isEmpty == false,
           let urlString = JSONPath.resolveString(artworkPath, in: item),
           let artworkURL = URL(string: urlString) {
            let type: ArtworkType = mediaKind == .movie ? .poster : .season
            result.remoteArtworks = [Artwork(url: artworkURL, thumbURL: artworkURL, service: source.name, type: type, size: .default)]
        }

        return result
    }
}
