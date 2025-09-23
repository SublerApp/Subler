//
//  iTunesStore.swift
//  Subler
//
//  Created by Damiano Galassi on 25/07/2017.
//

import Foundation
import MP42Foundation

// MARK: - Data Types

extension KeyedDecodingContainer {

    public func decodeIntOrString(forKey key: KeyedDecodingContainer<K>.Key) throws -> Int {
        do {
            return try self.decode(Int.self, forKey: key)
        } catch {
            if let stringValue = try? self.decode(String.self, forKey: key),
                let intValue = Int(stringValue){
                return intValue
            } else {
                throw error
            }
        }
    }

    public func decodeIntOrStringIfPresent(forKey key: KeyedDecodingContainer<K>.Key) throws -> Int? {
        do {
            return try self.decodeIfPresent(Int.self, forKey: key)
        } catch {
            if let stringValue = try self.decodeIfPresent(String.self, forKey: key) {
                return Int(stringValue)
            } else {
                throw error
            }
        }
    }

}

private struct Artist : Codable {
    let artistId: Int
    let artistLinkUrl: URL?
    let artistName: String
    let artistType: String?
    let primaryGenreId: Int?
    let primaryGenreName: String?
}

extension Artist {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        artistId = try container.decodeIntOrString(forKey: .artistId)
        artistLinkUrl = try container.decodeIfPresent(URL.self, forKey: .artistLinkUrl)
        artistName = try container.decode(String.self, forKey: .artistName)
        artistType = try container.decodeIfPresent(String.self, forKey: .artistType)
        primaryGenreId = try container.decodeIntOrStringIfPresent(forKey: .primaryGenreId)
        primaryGenreName = try container.decodeIfPresent(String.self, forKey: .primaryGenreName)
    }
}

private struct Collection : Codable {
    let artistId: Int
    let artistName: String
    let artistViewUrl: URL?
    let artworkUrl100: URL?
    let artworkUrl60: URL?
    let collectionCensoredName: String?
    let collectionExplicitness: String?
    let collectionId: Int
    let collectionName: String
    let collectionType: String
    let collectionViewUrl: String?
    let contentAdvisoryRating: String?
    let copyright: String?
    let country: String?
    let currency: String?
    let longDescription: String?
    let primaryGenreName: String?
    let releaseDate: String?
    let trackCount: Int?
}

extension Collection {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artistId = try container.decodeIntOrString(forKey: .artistId)
        artistName = try container.decode(String.self, forKey: .artistName)
        artistViewUrl = try container.decodeIfPresent(URL.self, forKey: .artistViewUrl)
        artworkUrl100 = try container.decodeIfPresent(URL.self, forKey: .artworkUrl100)
        artworkUrl60 = try container.decodeIfPresent(URL.self, forKey: .artworkUrl60)
        collectionCensoredName = try container.decodeIfPresent(String.self, forKey: .collectionCensoredName)
        collectionExplicitness = try container.decodeIfPresent(String.self, forKey: .collectionExplicitness)
        collectionId = try container.decodeIntOrString(forKey: .collectionId)
        collectionName = try container.decode(String.self, forKey: .collectionName)
        collectionType = try container.decode(String.self, forKey: .collectionType)
        collectionViewUrl = try container.decodeIfPresent(String.self, forKey: .collectionViewUrl)
        contentAdvisoryRating = try container.decodeIfPresent(String.self, forKey: .contentAdvisoryRating)
        copyright = try container.decodeIfPresent(String.self, forKey: .copyright)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        longDescription = try container.decodeIfPresent(String.self, forKey: .longDescription)
        primaryGenreName = try container.decodeIfPresent(String.self, forKey: .primaryGenreName)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount)
    }
}

private struct Track : Codable {
    let artistName: String
    let artworkUrl100: URL?
    let artworkUrl30: URL?
    let artworkUrl60: URL?
    let artistId: Int?
    let collectionArtistId: Int?
    let collectionArtistViewUrl: URL?
    let collectionCensoredName: String?
    let collectionExplicitness: String?
    let collectionId: Int?
    let collectionName: String?
    let collectionViewUrl: URL?
    let contentAdvisoryRating: String?
    let country: String?
    let currency: String?
    let discCount: Int?
    let discNumber: Int?
    let hasITunesExtras: Bool?
    let kind: String?
    let shortDescription: String?
    let longDescription: String?
    let previewUrl: URL?
    let primaryGenreName: String?
    let releaseDate: String?
    let trackCensoredName: String?
    let trackCount: Int?
    let trackExplicitness: String?
    let trackId: Int?
    let trackName: String?
    let trackNumber: Int?
    let trackTimeMillis: Double?
    let trackViewUrl: URL?
    let wrapperType: String
}

extension Track {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        artistName = try container.decode(String.self, forKey: .artistName)
        artworkUrl100 = try container.decodeIfPresent(URL.self, forKey: .artworkUrl100)
        artworkUrl30 = try container.decodeIfPresent(URL.self, forKey: .artworkUrl30)
        artworkUrl60 = try container.decodeIfPresent(URL.self, forKey: .artworkUrl60)
        artistId = try container.decodeIntOrStringIfPresent(forKey: .artistId)
        collectionArtistId = try container.decodeIntOrStringIfPresent(forKey: .collectionArtistId)
        collectionArtistViewUrl = try container.decodeIfPresent(URL.self, forKey: .collectionArtistViewUrl)
        collectionCensoredName = try container.decodeIfPresent(String.self, forKey: .collectionCensoredName)
        collectionExplicitness = try container.decodeIfPresent(String.self, forKey: .collectionExplicitness)
        collectionId = try container.decodeIntOrStringIfPresent(forKey: .collectionId)
        collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)
        collectionViewUrl = try container.decodeIfPresent(URL.self, forKey: .collectionViewUrl)
        contentAdvisoryRating = try container.decodeIfPresent(String.self, forKey: .contentAdvisoryRating)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        discCount = try container.decodeIfPresent(Int.self, forKey: .discCount)
        discNumber = try container.decodeIfPresent(Int.self, forKey: .discNumber)
        hasITunesExtras = try container.decodeIfPresent(Bool.self, forKey: .hasITunesExtras)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        shortDescription = try container.decodeIfPresent(String.self, forKey: .shortDescription)
        longDescription = try container.decodeIfPresent(String.self, forKey: .longDescription)
        previewUrl = try container.decodeIfPresent(URL.self, forKey: .previewUrl)
        primaryGenreName = try container.decodeIfPresent(String.self, forKey: .primaryGenreName)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        trackCensoredName = try container.decodeIfPresent(String.self, forKey: .trackCensoredName)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount)
        trackExplicitness = try container.decodeIfPresent(String.self, forKey: .trackExplicitness)
        trackId = try container.decodeIntOrStringIfPresent(forKey: .trackId)
        trackName = try container.decodeIfPresent(String.self, forKey: .trackName)
        trackNumber = try container.decodeIfPresent(Int.self, forKey: .trackNumber)
        trackTimeMillis = try container.decodeIfPresent(Double.self, forKey: .trackTimeMillis)
        trackViewUrl = try container.decodeIfPresent(URL.self, forKey: .trackViewUrl)
        wrapperType = try container.decode(String.self, forKey: .wrapperType)
    }
}
public struct iTunesStore: MetadataService {

    private func sendJSONRequest<T>(url: URL, type: T.Type) -> T? where T : Decodable {
        guard let data = URLSession.data(from: url)
            else { return nil }
        
        do {
            let result = try JSONDecoder().decode(type, from: data)
            return result
        } catch {
            print("error: \(error)")
        }

        return nil
    }

    private struct Wrapper<T> : Codable where T : Codable {
        let resultCount: Int
        let results: [T]
    }

    struct Store : Codable {
        let storeCode: Int
        let country3: String
        let country2: String
        let language2: String
        let language: String
        let season: String
        let country: String
        let cast: String
        let director: String
        let producer: String
        let screenwriter: String
        let studio: String
        let copyright: String

        fileprivate static let stores: [Store] = {
            guard let url = Bundle.main.url(forResource: "iTunesStores", withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let result = try? JSONDecoder().decode([Store].self, from: data)
                else { return [] }
            return result
        }()

        init?(language: String) {
            guard let store = Store.stores.first(where :{ "\($0.country) (\($0.language))" == language }) else { return nil }
            self.storeCode = store.storeCode
            self.country3 = store.country3
            self.country2 = store.country2
            self.language2 = store.language2
            self.language = store.language
            self.season = store.season
            self.country = store.country
            self.cast = store.cast
            self.director = store.director
            self.producer = store.producer
            self.screenwriter = store.screenwriter
            self.studio = store.studio
            self.copyright = store.copyright
        }
    }

    public var languages: [String] {
        get {
            return Store.stores.map { "\($0.country) (\($0.language))" }
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
        return "iTunes Store"
    }

    // MARK: - TV Series name search

    public func search(tvShow: String, language: String) -> [String] {
        let searchTerm = tvShow.urlEncoded()

        if searchTerm.isEmpty == false,
            let store = Store(language: language),
            let url = URL(string: "https://itunes.apple.com/search?country=\(store.country2)&lang=\(store.language2.lowercased())&term=\(searchTerm)&media=tvShow&entity=tvEpisode&attribute=tvSeasonTerm&limit=200"),
            let results = sendJSONRequest(url: url, type: Wrapper<Artist>.self)?.results, results.isEmpty == false {

            let filteredResults = results.filter { $0.artistName.isEmpty == false }
            let sortedResults = filteredResults.sorted(by: { (a1, a2) -> Bool in
                return a1.artistName.minimumEditDistance(other: tvShow) > a2.artistName.minimumEditDistance(other: tvShow) ? false : true
            })

            return sortedResults.compactMap { $0.artistName }
        } else {
            return [];
        }
    }

    // MARK: - Quick iTunes search for metadata

    public static func quickiTunesSearch(tvSeriesName: String, seasonNum: Int?, episodeNum: Int?) -> MetadataResult? {
        // Could use some conversion from language to iTunes Store.
        return iTunesStore().search(tvShow: tvSeriesName, language: MetadataPrefs.tvShowiTunesStoreLanguage, season: seasonNum, episode: episodeNum).first
    }

    public static func quickiTunesSearch(movieName: String) -> MetadataResult? {
        // Could use some conversion from language to iTunes Store.
        return iTunesStore().search(movie: movieName, language: MetadataPrefs.movieiTunesStoreLanguage).first
    }

    // MARK: - Helpers

    private func areInIncreasingOrder(ep1: MetadataResult, ep2: MetadataResult) -> Bool {
        guard let v1 = ep1[.episodeNumber] as? Int,
            let v2 = ep2[.episodeNumber] as? Int,
            let s1 = ep1[.season] as? Int,
            let s2 = ep2[.season] as? Int
            else { return false }

        if s1 == s2 {
            return v1 > v2 ? false : true
        }
        else {
            return s1 > s2 ? false : true
        }
    }

    private func artwork(url: URL?, isTVShow: Bool) -> Artwork? {
        guard let regex = try? NSRegularExpression(pattern: "(\\{.*?\\})", options: [.caseInsensitive]),
            let url = url else { return nil }

        var text = url.absoluteString
        let replacement = isTVShow ? "800x800bb" : "1000x1000bb"
        let matchRange = regex.rangeOfFirstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))

        if matchRange.length > 0 {
            text = text.replacingCharacters(in: Range(matchRange, in: text)!, with: "bb")
        }

        if let artworkURL = URL(string: text),
            let artworkFullSizeURL = URL(string: text.replacingOccurrences(of: "100x100bb", with: replacement)) {
            let size = isTVShow ? ArtworkSize.square : .standard
            let type = isTVShow ? ArtworkType.season : .poster
            return Artwork(url:artworkFullSizeURL, thumbURL: artworkURL, service: self.name, type: type, size: size)
        }

        return nil
    }

    // MARK: - Search for TV episode metadata

    private func extractID(result: Collection, show: String, season: Int, store: Store) -> Int? {
        let showPattern = show.replacingOccurrences(of: " ", with: ".*?")
        let seasonPattern = "\(store.season)\\s\(season)$"

        guard let showRegex = try? NSRegularExpression(pattern: showPattern, options: [.caseInsensitive]) else { return nil }
        guard let seasonRegex = try? NSRegularExpression(pattern: seasonPattern, options: [.caseInsensitive]) else { return nil }

        // Skip if the artistName doesn't match the show
        if showRegex.matches(in: result.artistName, options: [], range: NSRange(result.artistName.startIndex..., in: result.artistName)).isEmpty {
            return nil
        }

        if result.collectionType != "TV Season" {
            return nil
        }

        if seasonRegex.matches(in: result.collectionName, options: [], range: NSRange(result.collectionName.startIndex..., in: result.collectionName)).isEmpty {
            return nil
        }

        return result.collectionId
    }

    private func extractID(result: Artist, show: String, store: Store) -> Int? {
        let showPattern = show.replacingOccurrences(of: " ", with: ".*?")
        guard let showRegex = try? NSRegularExpression(pattern: showPattern, options: [.caseInsensitive]) else { return nil }

        // Skip if the artistName doesn't match the show
        if showRegex.matches(in: result.artistName, options: [], range: NSRange(result.artistName.startIndex..., in: result.artistName)).isEmpty {
            return nil
        }

        if result.artistType != "TV Show" {
            return nil
        }

        return result.artistId
    }

    private func findiTunesIDs(seriesName: String, seasonNum: Int?, store: Store, relaxSearch: Bool) -> [Int] {
        // Determine artistId/collectionId
        guard let url = { () -> URL? in
            if let seasonNum = seasonNum {
                let searchTerm = "\(seriesName) \(store.season) \(seasonNum)".urlEncoded()
                if relaxSearch {
                    return URL(string: "https://itunes.apple.com/search?term=\(searchTerm)&media=tvShow&entity=tvSeason&country=\(store.country2)&lang=\(store.language2.lowercased())&limit=200")
                } else {
                    return URL(string: "https://itunes.apple.com/search?term=\(searchTerm)&media=tvShow&attribute=tvSeasonTerm&entity=tvSeason&country=\(store.country2)&lang=\(store.language2.lowercased())&limit=200")
                }
            } else {
                let searchTerm = seriesName.urlEncoded()
                if relaxSearch {
                    return URL(string: "https://itunes.apple.com/search?term=\(searchTerm)&media=tvShow&entity=tvSeason&country=\(store.country2)&lang=\(store.language2.lowercased())&limit=200")
                } else {
                    return URL(string: "https://itunes.apple.com/search?term=\(searchTerm)&media=tvShow&attribute=showTerm&entity=tvShow&country=\(store.country2)&lang=\(store.language2.lowercased())&limit=200")
                }
            }
        }()
        else { return [] }

        if let seasonNum = seasonNum {
            if let results = sendJSONRequest(url: url, type: Wrapper<Collection>.self)?.results, results.isEmpty == false {

                let filteredResults = results.filter { $0.collectionName.isEmpty == false }

                let sortedResults = filteredResults.sorted(by: { (c1, c2) -> Bool in
                    return c1.collectionName.minimumEditDistance(other: seriesName) > c2.collectionName.minimumEditDistance(other: seriesName) ? false : true
                })

                let ids = sortedResults.compactMap { extractID(result: $0, show: seriesName, season: seasonNum, store: store) }
                if ids.isEmpty, let first = sortedResults.first, first.collectionName.isEmpty == false, first.collectionName.minimumEditDistance(other: seriesName) < 8 {
                    return [first.collectionId]
                } else {
                    return ids
                }
            }
        }
        else {
            if let results = sendJSONRequest(url: url, type: Wrapper<Artist>.self)?.results, results.isEmpty == false {

                let filteredResults = results.filter { $0.artistName.isEmpty == false }

                let sortedResults = filteredResults.sorted(by: { (a1, a2) -> Bool in
                    return a1.artistName.minimumEditDistance(other: seriesName) > a2.artistName.minimumEditDistance(other: seriesName) ? false : true
                })

                let ids = sortedResults.compactMap { extractID(result: $0, show: seriesName, store: store) }
                if ids.isEmpty, let first = sortedResults.first, first.artistName.isEmpty == false, first.artistName.minimumEditDistance(other: seriesName) < 30 {
                    return [first.artistId]
                } else {
                    return ids
                }
            }
        }

        return []
    }

    public func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult] {
        guard tvShow.isEmpty == false, let store = Store(language: language) else { return [] }

        // Determine artistId/collectionId
        let ids = { () -> [Int] in
            let idsWithSeason = self.findiTunesIDs(seriesName: tvShow, seasonNum: season, store: store, relaxSearch: false)
            if idsWithSeason.isEmpty == false { return idsWithSeason }
            let idsWithSeasonRelaxed = self.findiTunesIDs(seriesName: tvShow, seasonNum: season, store: store, relaxSearch: true)
            if idsWithSeasonRelaxed.isEmpty == false { return idsWithSeasonRelaxed }
            return self.findiTunesIDs(seriesName: tvShow, seasonNum: nil, store: store, relaxSearch: true)
        }()

        // If we have an ID, use the lookup API to get episodes for that show/season
        for id in ids {
            if let lookupUrl = URL(string: "https://itunes.apple.com/lookup?country=\(store.country2)&id=\(id)&entity=tvEpisode&limit=260"),
                let results = sendJSONRequest(url: lookupUrl, type: Wrapper<Track>.self) {

                var filteredResults = results.results.filter { $0.wrapperType == "track" } .map { metadata(forTVResult: $0, store: store) }

                compactMultipartSeasons(results: filteredResults)

                if let season = season {
                    filteredResults = filteredResults.filter { $0[.season] as! Int == season }
                }

                if let episode = episode {
                    filteredResults = filteredResults.filter { $0[.episodeNumber] as! Int == episode }
                }

                if filteredResults.isEmpty == false {
                    return filteredResults.sorted(by: areInIncreasingOrder)
                }
            }
        }

        return []
    }

    private func compactMultipartSeasons(results: [MetadataResult]) {
        let seasons = Dictionary(grouping: results.filter { $0[.serviceAdditionalContentID] != nil }, by: { $0[.season] as? Int })

        for (_, episodes) in seasons {
            let parts = Dictionary(grouping: episodes, by: { $0[.serviceAdditionalContentID] as! Int })
            let max = parts.mapValues { $0.compactMap { $0[.episodeNumber] as? Int } .max() ?? 0 }

            for (part, episodes) in parts {
                let min = episodes.compactMap { $0[.episodeNumber] as? Int } .min() ?? 0
                let count = max[part - 1] ?? 0

                for episode in episodes {
                    if min < count, let episodeNumber = episode[.episodeNumber] as? Int {
                        episode[.episodeNumber] = episodeNumber + count
                    }
                    episode[.serviceAdditionalContentID] = nil
                }
            }
        }
    }

    private func metadata(forTVResult result: Track, store: Store) -> MetadataResult {
        let metadata = MetadataResult()

        metadata.mediaKind = .tvShow

        metadata[.name]            = result.trackName
        metadata[.releaseDate]     = result.releaseDate
        metadata[.description]     = result.shortDescription
        metadata[.longDescription] = result.longDescription
        metadata[.seriesName]      = result.artistName
        metadata[.genre]           = result.primaryGenreName
        
        metadata[.episodeNumber] = result.trackNumber
        if let trackNumber = result.trackNumber, let trackCount = result.trackCount {
            metadata[.trackNumber]   = "\(trackNumber)/\(trackCount)"
        }
        metadata[.diskNumber]    = "1/1"
        metadata[.artistID]      = result.artistId
        metadata[.playlistID]    = result.collectionId

        if let s = result.collectionName?.lowercased() {
            var separated = s.components(separatedBy: ", \(store.season)")

            if separated.count <= 1 {
                separated = s.components(separatedBy: ", prequel")
            }
            if separated.count <= 1 {
                separated = s.components(separatedBy: ", season ")
            }
            if separated.count <= 1 {
                separated = s.components(separatedBy: ", book ")
            }
            if separated.count <= 1 {
                separated = s.components(separatedBy: ", vol. ")
            }
            if separated.count <= 1 {
                separated = s.components(separatedBy: ", collection ")
            }
            if separated.count <= 1 {
                separated = s.components(separatedBy: ", series ")
            }

            let (season, part) = { () -> (Int, Int?) in
                if separated.count > 1 {
                    let season = separated[1]
                    if season.contains("season") {
                        return (0, nil)
                    } else {
                        let subparts = season.split(separator: ",")
                        if subparts.count > 1 {
                            let seasonNum = Int(subparts[0].trimmingCharacters(in: CharacterSet.decimalDigits.inverted)) ?? 1
                            let partNum = Int(subparts[1].trimmingCharacters(in: CharacterSet.decimalDigits.inverted)) ?? 1
                            return (seasonNum, partNum);
                        } else {
                            let seasonNum = Int(separated[1].trimmingCharacters(in: CharacterSet.decimalDigits.inverted)) ?? 1
                            return (seasonNum, nil);
                        }
                    }
                } else {
                    return s.contains(", pt") || s.contains(", volume") || s.contains("complete series") ? (1, nil) : (0, nil)
                }
            }()

            metadata[.season] = season
            if let trackNumber = result.trackNumber {
                metadata[.episodeID] = String(format:"%d%02d", season, trackNumber)
            }

            if let part = part {
                metadata[.serviceAdditionalContentID] = part;
            }
        }

        if let contentAdvisoryRating = result.contentAdvisoryRating {
            metadata[.rating] = Ratings.shared.rating(countryCode: store.country, mediaKind: metadata.mediaKind, name: contentAdvisoryRating)?.iTunesCode
        }

        metadata[.iTunesCountry] = store.storeCode
        metadata[.iTunesURL] = result.trackViewUrl
        metadata[.contentID] = result.trackId
        metadata[.serviceContentID] = result.trackId

        if result.trackExplicitness == "explicit" {
            metadata.contentRating = 4
        }
        else if result.trackExplicitness == "cleaned" {
            metadata.contentRating = 2
        }

        if let artwork = artwork(url: result.artworkUrl100, isTVShow: true) {
            metadata.remoteArtworks = [artwork]
        }

        return metadata
    }

    // MARK: - Search for movie metadata
    
    public func search(movie: String, language: String) -> [MetadataResult] {
        guard let store = Store(language: language),
            let url = URL(string: "https://itunes.apple.com/search?country=\(store.country2)&lang=\(store.language2.lowercased())&term=\(movie.urlEncoded())&entity=movie&limit=150"),
            let results = sendJSONRequest(url: url, type: Wrapper<Track>.self)
        else { return [] }

        let filteredResults = results.results.filter { $0.wrapperType == "track" }
        return filteredResults.map { metadata(forMoviePartialResult: $0, store: store) }
    }

    private func metadata(forMoviePartialResult result: Track, store: Store) -> MetadataResult {
        let metadata = MetadataResult()

        metadata.mediaKind = .movie

        metadata[.name]            = result.trackName
        metadata[.releaseDate]     = result.releaseDate
        metadata[.description]     = result.longDescription
        metadata[.longDescription] = result.longDescription
        metadata[.director]        = result.artistName
        metadata[.genre]           = result.primaryGenreName

        if let contentAdvisoryRating = result.contentAdvisoryRating {
            metadata[.rating] = Ratings.shared.rating(countryCode: store.country, mediaKind: metadata.mediaKind, name: contentAdvisoryRating)?.iTunesCode
        }

        metadata[.iTunesCountry] = store.storeCode
        metadata[.iTunesURL] = result.trackViewUrl
        metadata[.contentID] = result.trackId
        metadata[.serviceContentID] = result.trackId

        if result.trackExplicitness == "explicit" {
            metadata.contentRating = 4
        }
        else if result.trackExplicitness == "cleaned" {
            metadata.contentRating = 2
        }

        if let artwork = artwork(url: result.artworkUrl100, isTVShow: false) {
            metadata.remoteArtworks = [artwork]
        }

        return metadata
    }

    // MARK: - Load additional metadata

    public func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        guard let store = Store(language: language),
              let playlistID = metadata[.playlistID] as? Int,
              let url = URL(string: "https://itunes.apple.com/lookup?country=\(store.country2)&lang=\(store.language2.lowercased())&id=\(playlistID)")
            else { return metadata }
        
        if let results = sendJSONRequest(url: url, type: Wrapper<Collection>.self) {
            metadata[.seriesDescription] = results.results.first?.longDescription
        }

        guard let tvShow = metadata[.seriesName] as? String,
              let season = metadata[.season] as? Int else { return metadata }

        let additionalArtworks = AppleTV().searchArtwork(term: tvShow, store: store, type: .tvShow(season: season))
        metadata.remoteArtworks.append(contentsOf: additionalArtworks)

        return metadata
    }

    /// Scrape people from iTunes Store website HTML
    private func read(type: String, in xml: XMLDocument) -> [String] {
        guard let nodes = try? xml.nodes(forXPath: "//dl[contains(@class,'cast-list__role')]") else { return [] }

        for node in nodes {
            guard let typeNodes = try? node.nodes(forXPath: "dt[contains(@class,'cast-list__term')]"),
                let valueNodes = try? node.nodes(forXPath: "dd[contains(@class,'cast-list__detail')]") else { continue }

            if let nodeType = typeNodes.first?.stringValue?.trimmingWhitespacesAndNewlinews(),
                nodeType.caseInsensitiveCompare(type) == ComparisonResult.orderedSame {
                return valueNodes.compactMap { $0.stringValue }
            }
        }

        return []
    }

    private struct WebpageMetadata : Codable {
        let data: WebpageData?
    }

    private struct WebpageData: Codable {
        let attributes: WebpageAttributes?
    }

    private struct WebpageAttributes : Codable {
        let copyright: String?
        let studio: String?
    }

    // Read the JSON data on the iTunes Store webpage
    private func readAttributes(xml: XMLDocument) -> WebpageAttributes? {
        guard let nodes = try? xml.nodes(forXPath: "//script[contains(@id,'shoebox-ember-data-store')]") else { return nil }

        for node in nodes {
            guard let string = node.stringValue, let data = string.data(using: .utf8) else { continue }

            do {
                return try JSONDecoder().decode(WebpageMetadata.self, from: data).data?.attributes
            } catch {}
        }

        return nil
    }

    public func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult {
        guard let store = Store(language: language),
              let url = metadata[.iTunesURL] as? URL,
              let data = URLSession.data(from: url),
              let xmlString = String(data: data, encoding: .utf8),
              let xml = try? XMLDocument(xmlString: xmlString, options: .documentTidyHTML)
        else { return metadata }

        if metadata[.director] == nil {
            metadata[.director] = read(type: store.director, in: xml).joined(separator: ", ")
        }
        metadata[.cast]          = read(type: store.cast, in: xml).joined(separator: ", ")
        metadata[.producers]     = read(type: store.producer, in: xml).joined(separator: ", ")
        metadata[.screenwriters] = read(type: store.screenwriter, in: xml).joined(separator: ", ")

        if let attributes = readAttributes(xml: xml) {
            metadata[.studio] = attributes.studio

            if var copyright = attributes.copyright {
                if let range = copyright.range(of: ". All Rights Reserved", options: .caseInsensitive,
                                               range: copyright.startIndex ..< copyright.endIndex, locale: nil) {
                    copyright.removeSubrange(range)
                }
                if let range = copyright.range(of: " by", options: .caseInsensitive,
                                               range: copyright.startIndex ..< copyright.endIndex, locale: nil) {
                    copyright.removeSubrange(range)
                }
                metadata[.copyright] = copyright
            }
        }

        guard let title = metadata[.name] as? String else { return metadata }

        let additionalArtworks = AppleTV().searchArtwork(term: title, store: store, type: .movie)
        metadata.remoteArtworks.append(contentsOf: additionalArtworks)

        return metadata
    }

}
