//
//  iTunesStore.swift
//  iTunes Artwork
//
//  Created by Damiano Galassi on 15/10/2019.
//  Copyright © 2019 Damiano Galassi. All rights reserved.
//

import Foundation

private extension MetadataResult {
    convenience init(item: AppleTV.Item) {
        self.init()

        self.mediaKind = .movie

        self[.name]            = item.title
        if let releaseDate = item.releaseDate {
            self[.releaseDate] = Date(timeIntervalSince1970: releaseDate / 1000)
        }
        self[.longDescription] = item.description

        self[.cast]            = item.rolesSummary?.cast?.joined(separator: ", ")
        self[.director]        = item.rolesSummary?.directors?.joined(separator: ", ")

        self[.iTunesURL]       = item.url.absoluteString
        self[.serviceSeriesID]       = item.id

        let urls = [item.images.coverArt16X9?.url/*, item.images.coverArt?.url*/]

        let artworks = urls.compactMap { $0}.compactMap { (url: String) -> Artwork? in
            let baseURL = url.replacingOccurrences(of: "{w}x{h}.{f}", with: "")
            if let artworkURL = URL(string: baseURL + AppleTV.fullSize), let thumbURL = URL(string: baseURL + AppleTV.thumbSize) {
                return Artwork(url: artworkURL, thumbURL: thumbURL, service: "iTunes", type: .rectangle)
            } else {
                return nil
            }
        }

        self.remoteArtworks = artworks
    }
}

public struct AppleTV: MetadataService {

    public var languages: [String] {
        get {
            return iTunesStore().languages
        }
    }

    public var languageType: LanguageType {
        get {
            return .custom
        }
    }

    public var defaultLanguage: String {
        return "USA (English)"
    }

    public var name: String {
        return "Apple TV"
    }

    private let detailsURL = "https://tv.apple.com/api/uts/v2/view/product/"
    private let searchURL = "https://tv.apple.com/api/uts/v2/uts/v2/search/incremental?"
    private let seasonsURL = "https://tv.apple.com/api/uts/v2/show/"
    private let options = "&utsk=0&caller=wta&v=36&pfm=desktop"

    fileprivate static let thumbSize = "329x185.jpg"
    fileprivate static let fullSize = "800x450.jpg"

    private func normalize(_ term: String) -> String {
        return term.replacingOccurrences(of: " (Dubbed)", with: "")
            .replacingOccurrences(of: " (Subtitled)", with: "")
            .replacingOccurrences(of: " (Ex-tended Edition)", with: "")
    }

    enum MediaType {
        case movie
        case tvShow(season: Int?)

        var description: String {
            get {
                switch self {
                case .movie:
                    return "Movie"
                case .tvShow:
                    return "Show"
                }
            }
        }
    }

    // MARK: - TV Series search

    public func search(tvShow: String, language: String) -> [String] {
        guard let store = iTunesStore.Store(language: language) else { return [] }

        let items = search(term: tvShow, store: store)
        return items.compactMap { $0.title }
    }

    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        guard let store = iTunesStore.Store(language: language) else { return [] }

        let items = search(term: tvShow, store: store, type: .tvShow(season: nil))
        let results = items.map { MetadataResult(item: $0) }
        return results
    }

    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        return MetadataResult()
    }


    // MARK: - Movie search

    public func search(movie: String, language: String) -> [MetadataResult] {
        guard let store = iTunesStore.Store(language: language) else { return [] }

        let items = search(term: movie, store: store)
        let results = items.map { MetadataResult(item: $0) }
        return results
    }

    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        guard let store = iTunesStore.Store(language: language),
            let id = metadata[.serviceSeriesID] as? String,
            let details = fetchMovieDetails(id: id, store: store) else { return metadata }

        let content = details.content

        metadata[.genre] = content.genres.map { $0.name }.joined(separator: ", ")
        metadata[.studio] = content.studio

        let rating = content.rating
        metadata[.rating] = "\(rating.system)|\(rating.name)|\(rating.value)|"

        metadata[.cast] = details.roles.filter { $0.type == RoleTitle.actor}.map { $0.personName }.joined(separator: ", ")
        metadata[.screenwriters] = details.roles.filter { $0.type == RoleTitle.writer}.map { $0.personName }.joined(separator: ", ")
        metadata[.producers] = details.roles.filter { $0.type == RoleTitle.producer}.map { $0.personName }.joined(separator: ", ")
        metadata[.director] = details.roles.filter { $0.type == RoleTitle.director}.map { $0.personName }.first

        return metadata
    }

    // MARK: - Artworks search

    private func searchSeasons(item: Item,  season: Int, store: iTunesStore.Store) -> [Artwork] {
        let urlString = "\(seasonsURL)\(item.id)/itunesSeasons?sf=\(store.storeCode)&locale=\(store.language2)\(options)"
        if let url = URL(string: urlString), let results = sendJSONRequest(url: url, type: Wrapper<Seasons>.self) {

            let filteredResults =  results.data.seasons.values.joined().filter { $0.seasonNumber == season }

            let urls = filteredResults.compactMap { $0.images }.compactMap { $0.coverArt16X9 }.compactMap { $0.url }

            let artworks = urls.compactMap { (url: String) -> Artwork? in
                let baseURL = url.replacingOccurrences(of: "{w}x{h}.{f}", with: "")
                if let artworkURL = URL(string: baseURL + AppleTV.fullSize), let thumbURL = URL(string: baseURL + AppleTV.thumbSize) {
                    return Artwork(url: artworkURL, thumbURL: thumbURL, service: "Apple TV", type: .rectangle)
                } else {
                    return nil
                }
            }

            return artworks
        }
        return []
    }

    func searchArtwork(term: String, store: iTunesStore.Store, type: MediaType = .movie) -> [Artwork] {
        let normalizedTerm = normalize(term)

        if let url = URL(string: "\(searchURL)&sf=\(store.storeCode)&locale=\(store.language2)\(options)&q=\(normalizedTerm.urlEncoded())"),
            let results = sendJSONRequest(url: url, type: Wrapper<Results>.self) {

            let filteredResults = { () -> [Item] in
                let items = results.data.canvas?.shelves
                    .flatMap { $0.items }
                    .filter { $0.type == type.description }

                if let results = items?.filter({ $0.title == normalizedTerm }), results.isEmpty == false {
                    return results
                } else if let results = items {
                    return results
                } else {
                    return []
                }
            }()

            let urls = filteredResults.compactMap { $0.images }.compactMap { $0.coverArt16X9 }.compactMap { $0.url }

            let artworks = urls.compactMap { (url: String) -> Artwork? in
                let baseURL = url.replacingOccurrences(of: "{w}x{h}.{f}", with: "")
                if let artworkURL = URL(string: baseURL + AppleTV.fullSize), let thumbURL = URL(string: baseURL + AppleTV.thumbSize) {
                    return Artwork(url: artworkURL, thumbURL: thumbURL, service: "Apple TV", type: .rectangle)
                } else {
                    return nil
                }
            }

            if case let MediaType.tvShow(season) = type, let item = filteredResults.first {
                if let season = season {
                    return artworks + searchSeasons(item: item, season: season, store: store)
                }
            }

            return artworks
        }
        return []
    }

    // MARK: Model

    private func sendJSONRequest<T>(url: URL, type: T.Type) -> T? where T : Decodable {
        guard let data = URLSession.data(from: url) else { return nil }

        do {
            let result = try JSONDecoder().decode(type, from: data)
            return result
        } catch {
            print("error: \(error)")
        }

        return nil
    }

    private func search(term: String, store: iTunesStore.Store, type: MediaType = .movie) -> [Item] {
        if let url = URL(string: "\(searchURL)&sf=\(store.storeCode)&locale=\(store.language2)\(options)&q=\(term.urlEncoded())"),
            let results = sendJSONRequest(url: url, type: Wrapper<Results>.self) {

            let filteredItems = results.data.canvas?.shelves
                .flatMap { $0.items }
                .filter { $0.type == type.description }

            return filteredItems ?? []
        }
        return []
    }

    private func fetchMovieDetails(id: String, store: iTunesStore.Store) -> ShowDetails? {
        if let url = URL(string: "\(detailsURL)\(id)?&sf=\(store.storeCode)&locale=\(store.language2)\(options)"),
            let results = sendJSONRequest(url: url, type: Wrapper<ShowDetails>.self) {
            return results.data
        }
        return nil
    }

    private struct Results: Codable {
        let q: String
        let canvas: Canvas?
    }

    private struct Wrapper<T>: Codable where T : Codable  {
        let data: T
    }

    fileprivate struct Image: Codable {
        let width: UInt
        let height: UInt
        let hasAlpha: Bool?
        let joeColor: String?
        let url: String
    }

    fileprivate struct Images: Codable {
        let bannerUberImage: Image?
        let contentLogo: Image?
        let coverArt: Image?
        let coverArt16X9: Image?
        let fullColorContentLogo: Image?
        let fullScreenBackground: Image?
        let previewFrame: Image?
    }

    fileprivate struct Rating: Codable {
        let displayName: String
        let name: String
        let system: String
        let value: UInt
    }

    private struct Genre: Codable {
        let name, id, type: String
        let url: String
    }

    fileprivate struct Roles: Codable {
        let cast: [String]?
        let directors: [String]?
    }

    private struct Role: Codable {
        let type, roleTitle: RoleTitle
        let characterName: String?
        let personName, personId: String
        let url: String
    }

    private enum RoleTitle: String, Codable {
        case actor = "Actor"
        case director = "Director"
        case producer = "Producer"
        case writer = "Writer"
        case voice = "Voice"
        case creator = "Creator"
    }

    fileprivate struct Item: Codable {
        let commonSenseRecommendedAge: UInt?
        let contentAdvisories: [String]?
        let description: String?
        let duration: UInt?
        let id: String
        let images: Images
        let isEntitledToPlay: Bool?
        let rating: Rating?
        let releaseDate: TimeInterval?
        let rolesSummary: Roles?
        let title: String?
        let tomatometerFreshness: String?
        let tomatometerPercentage: UInt?
        let type: String
        let url: URL
    }

    private struct ItemCollection: Codable {
        let displayType: String?
        let id: String?
        let items: [Item]
        let title: String
        let url: String?
        let version: String?
    }

    private struct Canvas: Codable {
        let id: String
        let shelves: [ItemCollection]
    }

    // MARK: Movie specific

    private struct Content: Codable {
        let id: String
        let type: String
        let isEntitledToPlay: Bool?
        let title, contentDescription: String
        let releaseDate: Int
        let genres: [Genre]
        let isUhd, isHdr: Bool?
        let rating: Rating
        let contentAdvisories: [String]?
        let tomatometerFreshness: String
        let tomatometerPercentage, commonSenseRecommendedAge: Int
        let images: Images
        let url: String
        let rolesSummary: Roles
        let duration: Int
        let version: String?
        let studio: String

        enum CodingKeys: String, CodingKey {
            case id, type, isEntitledToPlay, title
            case contentDescription = "description"
            case releaseDate, genres, isUhd, isHdr, rating, contentAdvisories, tomatometerFreshness, tomatometerPercentage, commonSenseRecommendedAge, images, url, rolesSummary, duration, version, studio
        }
    }

    private struct ShowDetails: Codable {
        let content: Content
        let roles: [Role]
    }

    // MARK: Season specific

    private struct Season: Codable {
        let id, canonicalId, type, title: String
        let images: Images
        let url: String
        let adamId: String
        let seasonNumber: Int
        let showId, showTitle: String
        let showImages: Images
    }

    private struct Seasons: Codable {
        let seasons: [String: [Season]]
    }

}
