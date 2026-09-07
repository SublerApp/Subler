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

    // MARK: - Test Connection / field discovery

    /// One field discovered in a sample response, alongside any error that
    /// kept the request from producing fields at all.
    public struct FieldDiscoveryResult {
        public let fields: [DiscoveredField]
        public let errorMessage: String?
    }

    /// Runs a real search with `query` and reports the fields found in the
    /// first result, so the Sources preferences pane can offer them for
    /// mapping instead of the user having to already know -- and type out
    /// by hand -- the response's shape. Synchronous, like the rest of this
    /// type; callers on the main thread should dispatch this to a
    /// background queue, same as any other search here.
    public func discoverFields(forQuery query: String) -> FieldDiscoveryResult {
        switch fetchRawItems(forQuery: query) {
        case .failure(let message):
            return FieldDiscoveryResult(fields: [], errorMessage: message)
        case .items(let items):
            guard let firstItem = items.first else {
                return FieldDiscoveryResult(fields: [], errorMessage: NSLocalizedString("The request succeeded but returned no results for that search term -- try a different one.", comment: ""))
            }
            let fields = JSONPath.discoverFields(in: firstItem)
            if fields.isEmpty {
                return FieldDiscoveryResult(fields: [], errorMessage: NSLocalizedString("No fields were found in the response.", comment: ""))
            }
            return FieldDiscoveryResult(fields: fields, errorMessage: nil)
        }
    }

    // MARK: - Request / response handling

    private enum RawFetchOutcome {
        case items([Any])
        case failure(String)
    }

    private func fetchRawItems(forQuery query: String) -> RawFetchOutcome {
        guard query.isEmpty == false else {
            return .failure(NSLocalizedString("Enter a sample search term first.", comment: ""))
        }
        guard let url = requestURL(forQuery: query) else {
            return .failure(NSLocalizedString("Couldn't build a request URL -- check the search URL template.", comment: ""))
        }

        let response = rawRequest(url: url, headers: requestHeaders())

        if let networkError = response.networkError {
            return .failure(String(format: NSLocalizedString("The request failed: %@", comment: ""), networkError))
        }
        guard let statusCode = response.statusCode else {
            return .failure(NSLocalizedString("No response was received -- check the URL and your network connection.", comment: ""))
        }
        guard (200...299).contains(statusCode) else {
            // A non-2xx response almost always means the request reached
            // the server fine and something about how it's configured is
            // wrong (a bad/missing API key, the wrong endpoint path) --
            // very different from a real network failure, and worth
            // telling apart. Surface whatever body came back too, since
            // most JSON APIs put the actual reason there (e.g.
            // {"message":"Unauthenticated."} for a bad token).
            let bodySnippet = response.data.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)
            if let bodySnippet = bodySnippet, bodySnippet.isEmpty == false {
                return .failure(String(format: NSLocalizedString("Server returned HTTP %d: %@", comment: ""), statusCode, String(bodySnippet)))
            }
            return .failure(String(format: NSLocalizedString("Server returned HTTP %d.", comment: ""), statusCode))
        }
        guard let data = response.data, let json = try? JSONSerialization.jsonObject(with: data) else {
            return .failure(NSLocalizedString("The response wasn't valid JSON.", comment: ""))
        }

        let items: [Any]
        if source.resultsPath.trimmingCharacters(in: .whitespaces).isEmpty {
            items = json as? [Any] ?? []
        } else {
            items = JSONPath.resolve(source.resultsPath, in: json) as? [Any] ?? []
        }
        return .items(items)
    }

    /// The result of a raw HTTP request, keeping the body even on a
    /// non-2xx response (NetworkUtilities.dataTask, used elsewhere in
    /// Subler, discards the body whenever the status code isn't 200 --
    /// fine for providers that only ever expect success, but this is the
    /// one place in the app whose whole job is telling the user why a
    /// request to a URL *they* configured didn't work).
    private struct RawResponse {
        let data: Data?
        let statusCode: Int?
        let networkError: String?
    }

    private func rawRequest(url: URL, headers: [String: String]) -> RawResponse {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30.0)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result = RawResponse(data: nil, statusCode: nil, networkError: nil)

        URLSession.shared.dataTask(with: request) { data, response, error in
            result = RawResponse(data: data,
                                  statusCode: (response as? HTTPURLResponse)?.statusCode,
                                  networkError: error?.localizedDescription)
            semaphore.signal()
        }.resume()

        semaphore.wait()
        return result
    }

    private func results(forQuery query: String, mediaKind: MediaKind) -> [MetadataResult] {
        guard case .items(let items) = fetchRawItems(forQuery: query) else { return [] }
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
