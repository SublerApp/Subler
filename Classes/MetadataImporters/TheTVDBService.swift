//
//  TheTVDBService.swift
//  Subler
//
//  Created by Damiano Galassi on 15/06/2017.
//

import Foundation
import MP42Foundation

public struct TVDBSeriesSearchResult : Codable {
    public let aliases: [String]
    public let banner: String?
    public let firstAired: String?
    public let id: Int
    public let imdbId: String?
    public let network: String?
    public let overview: String?
    public let seriesName: String?
    public let status: String
}

public struct TVDBSeriesInfo : Codable {
    public let added: String?
    public let airsDayOfWeek: String?
    public let airsTime: String?
    public let firstAired: String?

    public let aliases: [String]
    public let banner: String?
    public let genre: [String]

    public let id: Int
    public let imdbId: String?

    public let lastUpdated: Int?

    public let network: String?
    public let networkId: String?

    public let rating: String?
    public let runtime: String?

    public let seriesId: String
    public let seriesName: String
    public let overview: String?

    //public let siteRating: Double?
    //public let siteRatingCount: Double?

    //public let status: String?
}

public struct TVDBActor : Codable {
    public let id: Int
    public let name: String
    //public let role: String?
}

public struct TVDBRatingInfo : Codable {
    public let average: Double
    public let count: Int
}

public struct TVDBImage : Codable {
    public let fileName: String
    public let keyType: String
    public let ratingsInfo: TVDBRatingInfo?
    public let resolution: String?
    public let subKey: String?
    public let thumbnail: String
}

public struct TVDBEpisode : Codable {
    public let absoluteNumber: Double?
    public let airedEpisodeNumber: Int
    public let airedSeason: Int

    //public let dvdEpisodeNumber: Double?
    //public let dvdSeason: Double?

    public let episodeName: String?
    public let firstAired: String?

    public let id: Int
    public let overview: String?
}

public struct TVDBEpisodeInfo : Codable {
    public let absoluteNumber: Int?
    public let airedEpisodeNumber: Int?
    public let airedSeason: Int?

    public let directors: [String]

    //public let dvdEpisodeNumber: Double?
    //public let dvdSeason: Double?

    public let episodeName: String?
    public let filename: String?
    public let firstAired: String?

    public let guestStars: [String]

    public let id: Int
    public let overview: String?

    public let writers: [String]
}

private extension ArtworkType {
    var theTVDBName: String {
        switch self {
        case .poster:
            return "poster"
        case .season:
            return "season"
        default:
            return "poster"
        }
    }
}

final public class TheTVDBService {

    public static let sharedInstance = TheTVDBService()

    private let queue: DispatchQueue
    private let tokenQueue: DispatchQueue

    private let basePath = "https://api.thetvdb.com/"

    private struct Languages {
        let data: [String]
        let timestamp: TimeInterval
    }

    private var savedLanguages: Languages?

    public var languages: [String] {
        get {
            return ["en",
                    "sv",
                    "no",
                    "da",
                    "fi",
                    "nl",
                    "de",
                    "it",
                    "es",
                    "fr",
                    "pl",
                    "hu",
                    "el",
                    "tr",
                    "ru",
                    "he",
                    "ja",
                    "pt",
                    "zh",
                    "cs",
                    "sl",
                    "hr",
                    "ko"]
        }
    }

    private struct Token {
        let key: String
        let timestamp: TimeInterval
    }

    private var savedToken: Token?

    private var token: Token? {
        get {
            return tokenQueue.sync {
                if let result = savedToken, result.timestamp + 60 * 60 * 4 > Date.timeIntervalSinceReferenceDate  {
                    return result
                }
                else if let result = login() {
                    UserDefaults.standard.set(result.key, forKey: "SBTheTVBDToken")
                    UserDefaults.standard.set(result.timestamp, forKey: "SBTheTVBDTokenTimestamp")
                    savedToken = result
                    return result
                } else {
                    return nil
                }
            }
        }
    }

    private init() {
        queue = DispatchQueue(label: "org.subler.TheTVDBQueue")
        tokenQueue = DispatchQueue(label: "org.subler.TheTVDBTokenQueue")

        if let languagesArray = UserDefaults.standard.object(forKey: "SBTheTVBDLanguagesArray") as? [String] {
            let timestamp = UserDefaults.standard.double(forKey: "SBTheTVBDLanguagesArrayTimestamp")
            if timestamp + 60 * 60 * 24 * 30 > Date.timeIntervalSinceReferenceDate {
                savedLanguages = Languages(data: languagesArray, timestamp: timestamp)
            }
        }

        if let tokenKey = UserDefaults.standard.string(forKey: "SBTheTVBDToken") {
            let timestamp = UserDefaults.standard.double(forKey: "SBTheTVBDTokenTimestamp")
            if timestamp + 60 * 60 * 4 > Date.timeIntervalSinceReferenceDate {
                savedToken = Token(key: tokenKey, timestamp: timestamp)
            }
        }
    }

    private struct Wrapper<T> : Codable where T : Codable {
        let data: T
    }
    
    // MARK: - Login

    private func login() -> Token? {
        struct ApiKey : Codable {
            let apikey: String
        }

        struct TokenWrapper: Codable {
            let token: String
        }

        guard let apikey = try? JSONEncoder().encode(ApiKey(apikey: "3498815BE9484A62")) else { return nil }
        guard let url = URL(string: "https://api.thetvdb.com/login") else { return nil }

        let header = ["Content-Type" : "application/json",
                      "Accept" : "application/vnd.thetvdb.v3"]

        guard let response = URLSession.data(from: url,
                                             httpMethod: "POST",
                                             httpBody:apikey,
                                             header: header) else { return nil }

        guard let responseToken = try? JSONDecoder().decode(TokenWrapper.self, from: response) else { return nil }
        return Token(key: responseToken.token, timestamp: Date.timeIntervalSinceReferenceDate)
    }

    // MARK: - Languages

    private func fetchLanguages() -> Languages? {
        struct Language: Codable {
            let abbreviation: String
            let englishName: String
            let id: Int
            let name: String
        }

        guard let url = URL(string: "\(basePath)languages"),
            let result = sendJSONRequest(url: url, language: "en", type: Wrapper<[Language]>.self)
            else { return nil }

        let langManager = MP42Languages.defaultManager
        return Languages(data: result.data.map { langManager.extendedTag(forISO_639_1:$0.abbreviation) }, timestamp: Date.timeIntervalSinceReferenceDate)
    }

    // MARK: - Data request

    private func sendRequest(url: URL, language: String) -> Data? {
        guard let token = self.token else { return nil }

        let header = ["Authorization": "Bearer \(token.key)",
                      "Content-Type" : "application/json",
                      "Accept" : "application/vnd.thetvdb.v3",
                      "Accept-Language" : language]

        return URLSession.data(from: url, header: header)
    }

    private func sendJSONRequest<T>(url: URL, language: String, type: T.Type) -> T? where T : Decodable {
        guard let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(type, from: data)
            else { return nil }

        return result
    }

    // MARK: - Service calls
    
    public func fetch(series: String, language: String) -> [TVDBSeriesSearchResult] {
        // Remove + because it breaks search
        let encodedName = series.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "*", with: "-").urlEncoded()

        guard let url = URL(string: "\(basePath)search/series?name=\(encodedName)"),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<[TVDBSeriesSearchResult]>.self)
            else { return [] }

        return result.data
    }

    public func fetch(seriesInfo seriesID: Int, language: String) -> TVDBSeriesInfo? {
        guard let url = URL(string: "\(basePath)series/\(seriesID)"),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<TVDBSeriesInfo>.self)
            else { return nil }

        return result.data
    }

    public func fetch(actors seriesID: Int, language: String) -> [TVDBActor] {
        guard let url = URL(string: "\(basePath)series/\(seriesID)/actors"),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<[TVDBActor]>.self)
            else { return [] }

        return result.data
    }

    public func fetch(images seriesID: Int, type: ArtworkType, language: String) -> [TVDBImage] {
        guard let url = URL(string: "\(basePath)series/\(seriesID)/images/query?keyType=\(type.theTVDBName)"),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<[TVDBImage]>.self)
            else { return [] }

        return result.data
    }

    private func episodesURL(seriesID: Int, season: Int?, episode: Int?) -> URL? {
        switch (season, episode) {
        case let (season?, episode?):
            return URL(string: "\(basePath)series/\(seriesID)/episodes/query?airedSeason=\(season)&airedEpisode=\(episode)")
        case let (season?, _):
            return URL(string: "\(basePath)series/\(seriesID)/episodes/query?airedSeason=\(season)")
        default:
            return URL(string: "\(basePath)series/\(seriesID)/episodes")
        }
    }
    
    public func fetch(episodeForSeriesID seriesID: Int, season: Int?, episode: Int?, language: String) -> [TVDBEpisode] {
        guard let url = episodesURL(seriesID: seriesID, season: season, episode: episode),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<[TVDBEpisode]>.self)
            else { return [] }

        return result.data
    }

    public func fetch(episodeInfo episodeID: Int, language: String) -> TVDBEpisodeInfo? {
        guard let url = URL(string: "\(basePath)episodes/\(episodeID)"),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<TVDBEpisodeInfo>.self)
            else { return nil }

        return result.data
    }

}
