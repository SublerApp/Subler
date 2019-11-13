//
//  iTunesStore.swift
//  iTunes Artwork
//
//  Created by Damiano Galassi on 15/10/2019.
//  Copyright © 2019 Damiano Galassi. All rights reserved.
//

import Foundation

public struct AppleTV {
    
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

    private let detailsURL = "https://tv.apple.com/api/uts/v2/view/product/"
    private let searchURL = "https://tv.apple.com/api/uts/v2/uts/v2/search/incremental?"
    private let seasonsURL = "https://tv.apple.com/api/uts/v2/show/"
    private let options = "&utsk=0&caller=wta&v=36&pfm=desktop"

    private let thumbSize = "329x185.jpg"
    private let fullSize = "800x450.jpg"

    private func normalize(_ term: String) -> String {
        return term.replacingOccurrences(of: " (Dubbed)", with: "")
            .replacingOccurrences(of: " (Subtitled)", with: "")
            .replacingOccurrences(of: " (Ex-tended Edition)", with: "")
    }

    enum MediaType {
        case movie
        case tvShow(season: Int)

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

    func searchSeasons(item: Item,  season: Int, store: iTunesStore.Store) -> [Artwork] {
        let urlString = "\(seasonsURL)\(item.id)/itunesSeasons?sf=\(store.storeCode)&locale=\(store.language2)\(options)"
        if let url = URL(string: urlString), let results = sendJSONRequest(url: url, type: Wrapper<Seasons>.self) {

            let filteredResults =  results.data.seasons.values.joined().filter { $0.seasonNumber == season }

            let urls = filteredResults.compactMap { $0.images }.compactMap { $0.coverArt16X9 }.compactMap { $0.url }

            let artworks = urls.compactMap { (url: String) -> Artwork? in
                let baseURL = url.replacingOccurrences(of: "{w}x{h}.{f}", with: "")
                if let artworkURL = URL(string: baseURL + fullSize), let thumbURL = URL(string: baseURL + thumbSize) {
                    return Artwork(url: artworkURL, thumbURL: thumbURL, service: "iTunes", type: .rectangle)
                } else {
                    return nil
                }
            }

            return artworks
        }
        return []
    }

    func search(term: String, store: iTunesStore.Store, type: MediaType = .movie) -> [Artwork] {
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
                if let artworkURL = URL(string: baseURL + fullSize), let thumbURL = URL(string: baseURL + thumbSize) {
                    return Artwork(url: artworkURL, thumbURL: thumbURL, service: "iTunes", type: .rectangle)
                } else {
                    return nil
                }
            }

            if case let MediaType.tvShow(season) = type, let item = filteredResults.first {
                return artworks + searchSeasons(item: item, season: season, store: store)
            }

            return artworks
        }
        return []
    }

    struct Image: Codable {
        let width: UInt
        let height: UInt
        let hasAlpha: Bool?
        let joeColor: String?
        let url: String
    }

    struct Images: Codable {
        let bannerUberImage: Image?
        let contentLogo: Image?
        let coverArt: Image?
        let coverArt16X9: Image?
        let fullColorContentLogo: Image?
        let fullScreenBackground: Image?
        let previewFrame: Image?
    }

    struct Rating: Codable {
        let displayName: String
        let name: String
        let system: String
        let value: UInt
    }

    struct Roles: Codable {
        let cast: [String]?
        let directors: [String]?
    }

    struct Item: Codable {
        let commonSenseRecommendedAge: UInt?
        let contentAdvisories: [String]?
        let description: String?
        let duration: UInt?
        let id: String
        let images: Images
        let isEntitledToPlay: Bool?
        let rating: Rating?
        let releaseDate: Int64?
        let rolesSummary: Roles?
        let title: String?
        let tomatometerFreshness: String?
        let tomatometerPercentage: UInt?
        let type: String
        let url: URL
    }

    struct ItemCollection: Codable {
        let displayType: String?
        let id: String?
        let items: [Item]
        let title: String
        let url: String?
        let version: String?
    }

    struct Canvas: Codable {
        let id: String
        let shelves: [ItemCollection]
    }

    struct Season: Codable {
        let id, canonicalId, type, title: String
        let images: Images
        let url: String
        let adamId: String
        let seasonNumber: Int
        let showId, showTitle: String
        let showImages: Images
    }

    struct Seasons: Codable {
        let seasons: [String: [Season]]
    }

    struct Results: Codable {
        let q: String
        let canvas: Canvas?
    }

    struct Wrapper<T>: Codable where T : Codable  {
        let data: T
    }

}
