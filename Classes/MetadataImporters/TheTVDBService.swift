//
//  TheTVDBService.swift
//  Subler
//
//  Created by Damiano Galassi on 15/06/2017.
//

import Foundation

public struct SeriesSearchResult : Codable {
    public let aliases: [String]
    public let banner: String?
    public let firstAired: String?
    public let id: Int
    public let network: String?
    public let overview: String?
    public let seriesName: String
    public let status: String?
}

public struct SeriesInfo : Codable {
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

public struct Actor : Codable {
    public let id: Int
    public let name: String
    //public let role: String?
}

public struct RatingInfo : Codable {
    public let average: Double
    public let count: Int
}

public struct Image : Codable {
    public let fileName: String
    public let keyType: String
    public let ratingsInfo: RatingInfo?
    public let resolution: String?
    public let subKey: String?
    public let thumbnail: String
}

public struct Episode : Codable {
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

public struct EpisodeInfo : Codable {
    public let absoluteNumber: Int
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

public class TheTVDBService {

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
            if let result = savedLanguages, result.data.count > 0 {
                return result.data
            }
            else if let result = fetchLanguages() {
                savedLanguages = result
                UserDefaults.standard.set(result.data, forKey: "SBTheTVBDLanguagesArray")
                UserDefaults.standard.set(result.timestamp, forKey: "SBTheTVBDLanguagesArrayTimestamp")
                return result.data
            }
            return ["en"]
        }
    }

    private struct Token {
        let key: String
        let timestamp: TimeInterval
    }

    private var savedToken: Token?

    private var token: Token? {
        get {
            var token: Token?
            tokenQueue.sync {
                if let result = savedToken, result.timestamp + 60 * 60 * 4 > Date.timeIntervalSinceReferenceDate  {
                    token = result
                }
                else if let result = login() {
                    UserDefaults.standard.set(result.key, forKey: "SBTheTVBDToken")
                    UserDefaults.standard.set(result.timestamp, forKey: "SBTheTVBDTokenTimestamp")
                    savedToken = result
                    token = result
                }
            }
            return token
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
                      "Accept" : "application/json"]

        guard let response = SBMetadataHelper.downloadData(from: url,
                                                           httpMethod: "POST",
                                                           httpBody:apikey,
                                                           headerOptions: header,
                                                           cachePolicy: .default) else { return nil }

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

        struct LanguageWrapper : Codable {
            let data: [Language]
        }

        guard let url = URL(string: basePath + "languages"),
            let result = sendJSONRequest(url: url, language: "en", type: LanguageWrapper.self)
            else { return nil }

        let langManager = MP42Languages.defaultManager
        return Languages(data: result.data.map { langManager.extendedTag(forISO_639_1:$0.abbreviation) }, timestamp: Date.timeIntervalSinceReferenceDate)
    }

    // MARK: - Data request

    private func sendRequest(url: URL, language: String) -> Data? {
        guard let token = self.token else { return nil }

        let header = ["Authorization": "Bearer " + token.key,
                      "Content-Type" : "application/json",
                      "Accept" : "application/json",
                      "Accept-Language" : language]

        return SBMetadataHelper.downloadData(from: url, httpMethod: "GET", httpBody: nil, headerOptions: header, cachePolicy: .default)
    }

    private func sendJSONRequest<T>(url: URL, language: String, type: T.Type) -> T? where T : Decodable {
        guard let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(type, from: data)
            else { return nil }

        return result
    }

    // MARK: - Service call

    public func fetch(series: String, language: String) -> [SeriesSearchResult] {
        struct SeriesSearchResultWrapper : Codable {
            let data: [SeriesSearchResult]
        }
        let encodedName = SBMetadataHelper.urlEncoded(series)

        guard let url = URL(string: basePath + "search/series?name=" + encodedName),
            let result = sendJSONRequest(url: url, language: language, type: SeriesSearchResultWrapper.self)
            else { return [SeriesSearchResult]() }

        return result.data
    }

    public func fetch(seriesInfo seriesID: Int, language: String) -> SeriesInfo? {
        struct SeriesInfoWrapper : Codable {
            let data: SeriesInfo
        }

        guard let url = URL(string: basePath + "series/" + String(seriesID)),
            let result = sendJSONRequest(url: url, language: language, type: SeriesInfoWrapper.self)
            else { return nil }

        return result.data
    }

    public func fetch(actors seriesID: Int, language: String) -> [Actor] {
        struct ActorsWrapper : Codable {
            let data: [Actor]
        }

        guard let url = URL(string: basePath + "series/" + String(seriesID) + "/actors"),
            let result = sendJSONRequest(url: url, language: language, type: ActorsWrapper.self)
            else { return [] }

        return result.data
    }

    public func fetch(images seriesID: Int, type: String, language: String) -> [Image] {
        struct ImagesWrapper : Codable {
            let data: [Image]
        }

        guard let url = URL(string: basePath + "series/" + String(seriesID) + "/images/query?keyType=" + type),
            let result = sendJSONRequest(url: url, language: language, type: ImagesWrapper.self)
            else { return [] }

        return result.data
    }

    private func episodesURL(seriesID: Int, season: String, episode: String) -> URL? {
        switch (season, episode) {
        case _ where season.count > 0 && episode.count > 0:
            return URL(string: basePath + "series/" + String(seriesID) +  "/episodes/query?airedSeason=" + season +  "&airedEpisode=" + episode)
        case _ where season.count > 0:
            return URL(string: basePath + "series/" + String(seriesID) +  "/episodes/query?airedSeason=" + season)
        default:
            return URL(string: basePath + "series/" + String(seriesID) +  "/episodes")
        }
    }

    public func fetch(episodeForSeriesID seriesID: Int, season: String, episode: String, language: String) -> [Episode] {
        struct EpisodesWrapper : Codable {
            let data: [Episode]
        }

        guard let url = episodesURL(seriesID: seriesID, season: season, episode: episode),
            let result = sendJSONRequest(url: url, language: language, type: EpisodesWrapper.self)
            else { return [] }

        return result.data
    }

    public func fetch(episodeInfo episodeID: Int, language: String) -> EpisodeInfo? {
        struct EpisodesInfoWrapper : Codable {
            let data: EpisodeInfo
        }

        guard let url = URL(string: basePath + "episodes/" + String(episodeID)),
            let result = sendJSONRequest(url: url, language: language, type: EpisodesInfoWrapper.self)
            else { return nil }

        return result.data
    }

}
