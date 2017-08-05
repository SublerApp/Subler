//
//  iTunesStore.swift
//  Subler
//
//  Created by Damiano Galassi on 25/07/2017.
//

import Foundation

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

    private struct Store : Codable {
        let storeCode: Int
        let country3: String
        let country2: String
        let language2: String
        let language: String
        let season: String
        let country: String
        let actor: String
        let director: String
        let producer: String
        let screenwriter: String
    }

    private static let stores: [Store] = {
        guard let url = Bundle.main.url(forResource: "iTunesStores", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let result = try? JSONDecoder().decode([Store].self, from: data)
            else { return [] }
        return result
    }()

    private static func store(language: String) -> Store? {
        return iTunesStore.stores.filter { "\($0.country) (\($0.language))" == language }.first
    }

    public var languages: [String] {
        get {
            return iTunesStore.stores.map { "\($0.country) (\($0.language))" }
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

    // MARK: - Quick iTunes search for metadata

    public static func quickiTunesSearch(tvSeriesName: String, seasonNum: Int, episodeNum: Int) -> SBMetadataResult? {
        guard let language = UserDefaults.standard.string(forKey: "SBMetadataPreference|TV|iTunes Store|Language") else { return nil }
        return iTunesStore().search(TVSeries: tvSeriesName, language: language, season: seasonNum, episode: episodeNum).first
    }

    public static func quickiTunesSearch(movieName: String) -> SBMetadataResult? {
        guard let language = UserDefaults.standard.string(forKey: "SBMetadataPreference|Movie|iTunes Store|Language") else { return nil }
        return iTunesStore().search(movie: movieName, language: language).first
    }

    // MARK: - Data Types

    private struct Artist : Codable {
        let artistId: Int
        let artistLinkUrl: URL?
        let artistName: String
        let artistType: String
        let primaryGenreId: Int?
        let primaryGenreName: String?
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

    // MARK: - Helpers

    private func areInIncreasingOrder(ep1: SBMetadataResult, ep2: SBMetadataResult) -> Bool {
        guard let v1 = ep1[SBMetadataResultEpisodeNumber] as? Int,
            let v2 = ep2[SBMetadataResultEpisodeNumber] as? Int,
            let s1 = ep1[SBMetadataResultSeason] as? Int,
            let s2 = ep2[SBMetadataResultSeason] as? Int
            else { return false }

        if s1 == s2 {
            return v1 > v2 ? false : true
        }
        else {
            return s1 > s2 ? false : true
        }
    }

    private func artwork(url: URL?, isTVShow: Bool) -> RemoteImage? {
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
            return RemoteImage(url:artworkFullSizeURL, thumbURL:artworkURL, providerName:"iTunes")
        }

        return nil
    }

    // MARK: - Search for TV episode metadata

    private func extractID(results: [Collection], show: String, season: Int, store: Store) -> Int? {
        let showPattern = show.replacingOccurrences(of: " ", with: ".*?")
        let seasonPattern = "\(store.season)\\s\(season)$"

        guard let showRegex = try? NSRegularExpression(pattern: showPattern, options: [.caseInsensitive]) else { return nil }
        guard let seasonRegex = try? NSRegularExpression(pattern: seasonPattern, options: [.caseInsensitive]) else { return nil }

        for result in results {

            // Skip if the artistName doesn't match the show
            if showRegex.matches(in: result.artistName, options: [], range: NSRange(result.artistName.startIndex..., in: result.artistName)).isEmpty {
                continue
            }

            if result.collectionType != "TV Season" {
                continue
            }

            if seasonRegex.matches(in: result.collectionName, options: [], range: NSRange(result.collectionName.startIndex..., in: result.collectionName)).isEmpty {
                continue
            }

            return result.collectionId
        }

        return nil
    }

    private func extractID(results: [Artist], show: String, store: Store) -> Int? {
        let showPattern = show.replacingOccurrences(of: " ", with: ".*?")
        guard let showRegex = try? NSRegularExpression(pattern: showPattern, options: [.caseInsensitive]) else { return nil }

        for result in results {
            // Skip if the artistName doesn't match the show
            if showRegex.matches(in: result.artistName, options: [], range: NSRange(result.artistName.startIndex..., in: result.artistName)).isEmpty {
                continue
            }

            if result.artistType != "TV Show" {
                continue
            }

            return result.artistId
        }

        return nil
    }

    private func findiTunesID(seriesName: String, seasonNum: Int?, store: Store) -> Int? {
        // Determine artistId/collectionId
        guard let url = { () -> URL? in
            if let seasonNum = seasonNum {
                let searchTerm = "\(seriesName) \(store.season) \(seasonNum)".urlEncoded()
                return URL(string: "https://itunes.apple.com/search?country=\(store.country2)&lang=\(store.language2.lowercased())&term=\(searchTerm)&attribute=tvSeasonTerm&entity=tvSeason&limit=250")
            }
            else {
                let searchTerm = seriesName.urlEncoded()
                return URL(string: "https://itunes.apple.com/search?country=\(store.country2)&lang=\(store.language2.lowercased())&term=\(searchTerm)&attribute=showTerm&entity=tvShow&limit=250")
            }
        }()
        else { return nil }

        if let seasonNum = seasonNum {
            if let results = sendJSONRequest(url: url, type: Wrapper<Collection>.self) {
                return extractID(results: results.results, show: seriesName, season: seasonNum, store: store)
            }
        }
        else {
            if let results = sendJSONRequest(url: url, type: Wrapper<Artist>.self) {
                return extractID(results: results.results, show: seriesName, store: store)
            }
        }

        return nil
    }

    public func search(TVSeries: String, language: String, season: Int?, episode: Int?) -> [SBMetadataResult] {
        guard let store = iTunesStore.store(language: language) else { return [] }

        // Determine artistId/collectionId
        guard let id = { () -> Int? in
            if let id = findiTunesID(seriesName: TVSeries, seasonNum: season, store: store) { return id }
            else if let id = findiTunesID(seriesName: TVSeries, seasonNum: season, store: store) { return id }
            else { return nil }
            }()
        else { return [] }

        // If we have an ID, use the lookup API to get episodes for that show/season
        if let lookupUrl = URL(string: "https://itunes.apple.com/lookup?country=\(store.country2)&id=\(id)&entity=tvEpisode&limit=200"),
            let results = sendJSONRequest(url: lookupUrl, type: Wrapper<Track>.self) {

            var filteredResults = results.results.filter { $0.wrapperType == "track" } .map { metadata(forTVResult: $0, store: store) }

            if let season = season {
                filteredResults = filteredResults.filter { $0[SBMetadataResultSeason] as! Int == season }
            }

            if let episode = episode {
                filteredResults = filteredResults.filter { $0[SBMetadataResultEpisodeNumber] as! Int == episode }
            }

            return filteredResults.sorted(by: areInIncreasingOrder)
        }

        return []
    }

    private func metadata(forTVResult result: Track, store: Store) -> SBMetadataResult {
        let metadata = SBMetadataResult()

        metadata.mediaKind = 10 // TV show

        metadata[SBMetadataResultName]            = result.trackName
        metadata[SBMetadataResultReleaseDate]     = result.releaseDate
        metadata[SBMetadataResultDescription]     = result.shortDescription
        metadata[SBMetadataResultLongDescription] = result.longDescription
        metadata[SBMetadataResultSeriesName]      = result.artistName
        metadata[SBMetadataResultGenre]           = result.primaryGenreName
        
        metadata[SBMetadataResultEpisodeNumber] = result.trackNumber
        if let trackNumber = result.trackNumber, let trackCount = result.trackCount {
            metadata[SBMetadataResultTrackNumber]   = "\(trackNumber)/\(trackCount)"
        }
        metadata[SBMetadataResultDiskNumber]    = "1/1"
        metadata[SBMetadataResultArtistID]      = result.artistId
        metadata[SBMetadataResultPlaylistID]    = result.collectionId

        if let s = result.collectionName?.lowercased() {
            var separated = s.components(separatedBy: ", \(store.season)")
            
            if separated.count <= 1 {
                separated = s.components(separatedBy: ", season ")
            }
            if separated.count <= 1 {
                separated = s.components(separatedBy: ", book ")
            }

            let trackCount = result.trackCount ?? 1
            let season = separated.count > 1 ? Int(separated[1].trimmingCharacters(in: CharacterSet.whitespaces)) ?? 1 : trackCount > 1 ? 1 : 0

            metadata[SBMetadataResultSeason]    = season
            if let trackNumber = result.trackNumber {
                metadata[SBMetadataResultEpisodeID] = String(format:"%d%02d", season, trackNumber)
            }
        }

        if let contentAdvisoryRating = result.contentAdvisoryRating {
            metadata[SBMetadataResultRating] = MP42Ratings.defaultManager.ratingStringForiTunesCountry(store.country,
                                                                                                       media: metadata.mediaKind == 9 ? "movie" : "TV",
                                                                                                       ratingString: contentAdvisoryRating)
        }

        metadata[SBMetadataResultITunesCountry] = store.storeCode
        metadata[SBMetadataResultITunesURL] = result.trackViewUrl
        metadata[SBMetadataResultContentID] = result.trackId
        
        if result.trackExplicitness == "explicit" {
            metadata.contentRating = 4
        }
        else if result.trackExplicitness == "cleaned" {
            metadata.contentRating = 2
        }

        if let artwork = artwork(url: result.artworkUrl100, isTVShow: true) {
            metadata.remoteArtworks = [artwork].toClass()
        }

        return metadata
    }

    // MARK: - Search for movie metadata
    
    public func search(movie: String, language: String) -> [SBMetadataResult] {
        guard let store = iTunesStore.store(language: language),
            let url = URL(string: "https://itunes.apple.com/search?country=\(store.country2)&lang=\(store.language2)&term=\(movie.urlEncoded())&entity=movie&limit=150"),
            let results = sendJSONRequest(url: url, type: Wrapper<Track>.self)
        else { return [] }
        
        return results.results.map { metadata(forMoviePartialResult: $0, store: store) }
    }
    
    private func metadata(forMoviePartialResult result: Track, store: Store) -> SBMetadataResult {
        let metadata = SBMetadataResult()

        metadata.mediaKind = 9 // movie

        metadata[SBMetadataResultName]            = result.trackName
        metadata[SBMetadataResultReleaseDate]     = result.releaseDate
        metadata[SBMetadataResultDescription]     = result.longDescription
        metadata[SBMetadataResultLongDescription] = result.longDescription
        metadata[SBMetadataResultDirector]        = result.artistName
        metadata[SBMetadataResultGenre]           = result.primaryGenreName

        if let contentAdvisoryRating = result.contentAdvisoryRating {
            metadata[SBMetadataResultRating] = MP42Ratings.defaultManager.ratingStringForiTunesCountry(store.country,
                                                                                                       media: metadata.mediaKind == 9 ? "movie" : "TV",
                                                                                                       ratingString: contentAdvisoryRating)
        }

        metadata[SBMetadataResultITunesCountry] = store.storeCode
        metadata[SBMetadataResultITunesURL] = result.trackViewUrl
        metadata[SBMetadataResultContentID] = result.trackId
        
        if result.trackExplicitness == "explicit" {
            metadata.contentRating = 4
        }
        else if result.trackExplicitness == "cleaned" {
            metadata.contentRating = 2
        }

        if let artwork = artwork(url: result.artworkUrl100, isTVShow: false) {
            metadata.remoteArtworks = [artwork].toClass()
        }

        return metadata
    }

    // MARK: - Load additional metadata

    public func loadTVMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult {
        guard let store = iTunesStore.store(language: language),
              let playlistID = metadata[SBMetadataResultPlaylistID] as? Int,
              let url = URL(string: "https://itunes.apple.com/lookup?country=\(store.country2)&lang=\(store.language2.lowercased())&id=\(playlistID)")
            else { return metadata }
        
        if let results = sendJSONRequest(url: url, type: Wrapper<Collection>.self) {
            metadata[SBMetadataResultSeriesDescription] = results.results.first?.longDescription
        }

        return metadata
    }

    /// Scrape people from iTunes Store website HTML
    private func read(type: String, in xml: XMLDocument) -> [String] {
        guard let nodes = try? xml.nodes(forXPath: "//div[starts-with(@metrics-loc,'Titledbox_\(type)')]") else { return [] }

        for node in nodes {
            if let subXml = try? XMLDocument(xmlString: node.xmlString, options: []),
                let subNodes = try? subXml.nodes(forXPath: "//a") {
                return subNodes.flatMap { $0.stringValue }
            }
        }

        return []
    }

    public func loadMovieMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult {
        guard let store = iTunesStore.store(language: language),
              let url = metadata[SBMetadataResultITunesURL] as? URL,
              let data = URLSession.data(from: url),
              let xml = try? XMLDocument(data: data, options: .documentTidyHTML)
        else { return metadata }

        metadata[SBMetadataResultCast]          = read(type: store.actor, in: xml).joined(separator: ", ")
        metadata[SBMetadataResultDirector]      = read(type: store.director, in: xml).joined(separator: ", ")
        metadata[SBMetadataResultProducers]     = read(type: store.producer, in: xml).joined(separator: ", ")
        metadata[SBMetadataResultScreenwriters] = read(type: store.screenwriter, in: xml).joined(separator: ", ")

        if let nodes = try? xml.nodes(forXPath: "//li[@class='copyright']") {
            for node in nodes {
                if var copyright = node.stringValue {
                    copyright = copyright.replacingOccurrences(of: ". All Rights Reserved.", with: "")
                    copyright = copyright.replacingOccurrences(of: ". All rights reserved.", with: "")
                    copyright = copyright.replacingOccurrences(of: ". All Rights Reserved", with: "")
                    copyright = copyright.replacingOccurrences(of: ". All rights reserved", with: "")
                    copyright = copyright.replacingOccurrences(of: " by ", with: "")
                    metadata[SBMetadataResultCopyright] = copyright
                }
            }
        }

        return metadata
    }

}
