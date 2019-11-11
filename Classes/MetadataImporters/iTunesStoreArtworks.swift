//
//  iTunesStore.swift
//  iTunes Artwork
//
//  Created by Damiano Galassi on 15/10/2019.
//  Copyright © 2019 Damiano Galassi. All rights reserved.
//

import Foundation

public struct iTunesStoreArtworks {
    
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

    private let baseURL = "https://tv.apple.com/api/uts/v2/uts/v2/search/incremental?&utsk=0&caller=wta&v=36"
    private let seasonsURL = " https://uts-api.itunes.apple.com/uts/v2/show/umc.cmc.5ge1cirmxod01u8f8m3rplx5g/itunesSeasons?sf=143441&locale=it-IT&caller=wta&utsk=0&v=34"

    private func normalize(_ term: String) -> String {
        return term.replacingOccurrences(of: " (Dubbed)", with: "")
            .replacingOccurrences(of: " (Subtitled)", with: "")
            .replacingOccurrences(of: " (Ex-tended Edition)", with: "")
    }

    enum MediaType {
        case movie
        case tvShow

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

    func search(term: String, iTunesStore: Int, locale: String, type: MediaType = .movie) -> [Artwork] {
        let normalizedTerm = normalize(term)

        if let url = URL(string: "\(baseURL)&sf=\(iTunesStore)&pfm=desktop&locale=\(locale)&q=\(normalizedTerm.urlEncoded())"),
            let result = sendJSONRequest(url: url, type: Wrapper.self) {

            let filteredResults = { () -> [Item] in
                let items = result.data.canvas?.shelves
                    .flatMap { $0.items }
                    .filter { $0.type == type.description }

                if let results = items?.filter({ $0.title == normalizedTerm }),
                results.isEmpty == false {
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
                if let artworkURL = URL(string: baseURL + "1920x1080.jpg"), let thumbURL = URL(string: baseURL + "320x180.jpg") {
                    return Artwork(url: artworkURL, thumbURL: thumbURL, service: "iTunes", type: .rectangle)
                } else {
                    return nil
                }
            }
           return artworks
        }
        return []
    }

    func search(term: String, contentID: Int, iTunesStore: Int, locale: String, type: String = "Movies") -> [Artwork] {
        if let url = URL(string: "\(baseURL)&sf=\(iTunesStore)&pfm=desktop&locale=\(locale)&q=\(term.urlEncoded())"),
            let result = sendJSONRequest(url: url, type: Wrapper.self) {

            let contentID = String(contentID)
            if let filteredResults = result.data.canvas?.shelves.filter({ $0.title == type }).flatMap({ $0.items }) {
                let urls = filteredResults.compactMap { $0.images }.compactMap { $0.coverArt16X9 }.compactMap { $0.url }.filter { $0.contains(contentID) }

                let artworks = urls.compactMap { (url: String) -> Artwork? in
                    let baseURL = url.replacingOccurrences(of: "{w}x{h}.{f}", with: "")
                    if let artworkURL = URL(string: baseURL + "1920x1080.jpg"), let thumbURL = URL(string: baseURL + "320x180.jpg") {
                        return Artwork(url: artworkURL, thumbURL: thumbURL, service: "iTunes Store", type: .rectangle)
                    } else {
                        return nil
                    }
                }
                return artworks;
            }
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

    struct Result: Codable {
        let q: String
        let canvas: Canvas?
    }

    struct Wrapper: Codable {
        let data: Result
    }

}
