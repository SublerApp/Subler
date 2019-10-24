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
    
    private let baseURL = "https://tv.apple.com/api/uts/v2/uts/v2/search/incremental?&utsk=0&caller=0&v=31"
    
    func search(term: String, iTunesStore: Int, locale: String, type: String = "Movie") -> [Artwork] {
        if let url = URL(string: "\(baseURL)&sf=\(iTunesStore)&pfm=desktop&locale=\(locale)&q=\(term.urlEncoded())"),
            let result = sendJSONRequest(url: url, type: Wrapper.self) {

            let filteredResults = result.data.results.filter { $0.type == type }.flatMap { $0.items }.filter { $0.title == term }
            let urls = filteredResults.compactMap { $0.images }.compactMap { $0.coverArt16X9 }.compactMap { $0.url }

            let artworks = urls.compactMap { (url: String) -> Artwork? in
                let baseURL = url.replacingOccurrences(of: "{w}x{h}.{f}", with: "")
                if let artworkURL = URL(string: baseURL + "1920x1080.jpg"), let thumbURL = URL(string: baseURL + "320x180.jpg") {
                    return Artwork(url: artworkURL, thumbURL: thumbURL, service: "iTunes", type: .rectangle)
                } else {
                    return nil
                }
            }
            return artworks;
        }
        return []
    }
    
    func search(term: String, contentID: Int, iTunesStore: Int, locale: String, type: String = "Movie") -> [Artwork] {
        if let url = URL(string: "\(baseURL)&sf=\(iTunesStore)&pfm=desktop&locale=\(locale)&q=\(term.urlEncoded())"),
            let result = sendJSONRequest(url: url, type: Wrapper.self) {

            let contentID = String(contentID)
            let filteredResults = result.data.results.filter { $0.type == type }.flatMap { $0.items }
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
        return []
    }
    
    struct Target: Codable {
        let id: String
        let type: String
    }
    
    struct Image: Codable {
        let format: String
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
    
    struct Link: Codable {
        let target: Target
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
        let canonicalId: String?
        let commonSenseRecommendedAge: UInt?
        let contentAdvisories: [String]?
        let description: String?
        let duration: UInt?
        let id: String
        let images: Images
        let isEntitledToPlay: Bool?
        let links: Link
        let rating: Rating?
        let ratingValue: UInt?
        let releaseDate: UInt?
        let rolesSummary: Roles?
        let title: String?
        let tomatometerFreshness: String?
        let tomatometerPercentage: UInt?
        let type: String
        let url: URL
    }
    
    struct ItemCollection: Codable {
        let id: String
        let items: [Item]
        let locTitle: String
        let score: Double
        let type: String
    }
    
    struct Result: Codable {
        let q: String
        let results: [ItemCollection]
    }
    
    struct Wrapper: Codable {
        let data: Result
    }
    
}
