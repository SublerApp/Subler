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

    public let siteRating: Double?
    public let siteRatingCount: Double?

    public let status: String?
}

public struct Actor : Codable {
    public let id: Int
    public let name: String
    public let role: String?
}

public struct RatingInfo : Codable {
    public let average: Int
    public let count: Int
}

public struct Image : Codable {
    public let fileName: String
    public let keyType: String
    public let ratingsInfo: RatingInfo
    public let resolution: String
    public let subKey: String
    public let thumbnail: String
}

public struct Episode : Codable {
    public let absoluteNumber: Int?
    public let airedEpisodeNumber: Int
    public let airedSeason: Int

    public let dvdEpisodeNumber: Int?
    public let dvdSeason: Int?

    public let episodeName: String?
    public let firstAired: String?

    public let id: Int
    public let overview: String?
}

/*

 "absoluteNumber": 0,
 "airedEpisodeNumber": 0,
 "airedSeason": 0,
 "airsAfterSeason": 0,
 "airsBeforeEpisode": 0,
 "airsBeforeSeason": 0,
 "director": "string",
 "directors": [
 "string"
 ],
 "dvdChapter": 0,
 "dvdDiscid": "string",
 "dvdEpisodeNumber": 0,
 "dvdSeason": 0,
 "episodeName": "string",
 "filename": "string",
 "firstAired": "string",
 "guestStars": [
 "string"
 ],
 "id": 0,
 "imdbId": "string",
 "lastUpdated": 0,
 "lastUpdatedBy": "string",
 "overview": "string",
 "productionCode": "string",
 "seriesId": "string",
 "showUrl": "string",
 "siteRating": 0,
 "siteRatingCount": 0,
 "thumbAdded": "string",
 "thumbAuthor": 0,
 "thumbHeight": "string",
 "thumbWidth": "string",
 "writers": [
 "string"
 ]
 */

public struct EpisodeInfo : Codable {
    public let absoluteNumber: Int
    public let airedEpisodeNumber: Int?
    public let airedSeason: Int?

    public let director: String?
    public let directors: [String]

    public let dvdEpisodeNumber: Int?
    public let dvdSeason: Int?

    public let episodeName: String?
    public let firstAired: String?

    public let id: Int
    public let overview: String?

    public let writers: [String]
}

public class TheTVDBSession {

    public static let sharedInstance = TheTVDBSession()

    private let queue: DispatchQueue
    private let tokenQueue: DispatchQueue

    private var languagesTimestamp: TimeInterval
    public var languages: [String]

    private struct Token {
        let key: String
        let timestamp: TimeInterval
    }

    private var savedToken: Token?

    private var token: Token? {
        get {
            var result: Token?
            tokenQueue.sync {
                if let token = savedToken {
                    result = token
                }
                else {
                    result = login()
                }
            }
            return result
        }
    }

    private init() {
        queue = DispatchQueue(label: "org.subler.TheTVDBQueue")
        tokenQueue = DispatchQueue(label: "org.subler.TheTVDBTokenQueue")

        languagesTimestamp = UserDefaults.standard.double(forKey: "SBTheTVBDLanguagesArrayTimestamp")

        if languagesTimestamp + 60 * 60 * 24 * 30 > Date.timeIntervalSinceReferenceDate {
            languages = UserDefaults.standard.object(forKey: "SBTheTVBDLanguagesArray") as! [String]
        }
        else {
            languages = []
        }
    }

    private struct ApiKey : Codable {
        let apikey: String
    }

    private struct TokenWrapper: Codable {
        let token: String
    }

    private func login() -> Token? {
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

    private struct Language: Codable {
        let abbreviation: String
        let englishName: String
        let id: Int
        let name: String
    }

    private struct Languages : Codable {
        let data: [Language]
    }

    func fetchLanguages() {

    }

    private func sendRequest(url: URL, language: String) -> Data? {
        guard let token = self.token else { return nil }

        let header = ["Authorization": "Bearer " + token.key,
                      "Content-Type" : "application/json",
                      "Accept" : "application/json",
                      "Accept-Language" : language]

        return SBMetadataHelper.downloadData(from: url, httpMethod: "GET", httpBody: nil, headerOptions: header, cachePolicy: .default)
    }

    private struct SeriesSearchResultWrapper : Codable {
        let data: [SeriesSearchResult]
    }

    public func fetch(series: String, language: String) -> [SeriesSearchResult] {
        let encodedName = SBMetadataHelper.urlEncoded(series)

        guard let url = URL(string: "https://api.thetvdb.com/search/series?name=" + encodedName),
            let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(SeriesSearchResultWrapper.self, from: data)
            else { return [SeriesSearchResult]() }

        return result.data
    }

    private struct SeriesInfoWrapper : Codable {
        let data: SeriesInfo
    }

    public func fetch(seriesInfo seriesID: Int, language: String) -> SeriesInfo? {
        guard let url = URL(string: "https://api.thetvdb.com/series/" + String(seriesID)),
            let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(SeriesInfoWrapper.self, from: data)
            else { return nil }

        return result.data
    }

    private struct ActorsWrapper : Codable {
        let data: [Actor]
    }

    public func fetch(actors seriesID: Int, language: String) -> [Actor] {
        guard let url = URL(string: "https://api.thetvdb.com/series/" + String(seriesID) + "/actors"),
            let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(ActorsWrapper.self, from: data)
            else { return [Actor]() }

        return result.data
    }

    private struct ImagesWrapper : Codable {
        let data: [Image]
    }

    public func fetch(images seriesID: Int, type: String, language: String) -> [Image] {
        guard let url = URL(string: "https://api.thetvdb.com/series/" + String(seriesID) + "/images/query?keyType=" + type),
            let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(ImagesWrapper.self, from: data)
            else { return [Image]() }

        return result.data
    }
    
    private struct EpisodesWrapper : Codable {
        let data: [Episode]
    }

    private func episodesURL(seriesID: Int, season: String, episode: String) -> URL? {
        switch (season, episode) {
        case _ where season.count > 0 && episode.count > 0:
            return URL(string: "https://api.thetvdb.com/series/" + String(seriesID) +  "/episodes/query?airedSeason=" + season +  "&airedEpisode=" + episode)
        case _ where season.count > 0:
            return URL(string: "https://api.thetvdb.com/series/" + String(seriesID) +  "/episodes/query?airedSeason=" + season)
        default:
            return URL(string: "https://api.thetvdb.com/series/" + String(seriesID) +  "/episodes")
        }
    }

    public func fetch(episodeForSeriesID seriesID: Int, season: String, episode: String, language: String) -> [Episode] {
        guard let url = episodesURL(seriesID: seriesID, season: season, episode: episode),
            let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(EpisodesWrapper.self, from: data)
            else { return [Episode]() }

        return result.data
    }

    private struct EpisodesInfoWrapper : Codable {
        let data: EpisodeInfo
    }

    public func fetch(episodeInfo episodeID: Int, language: String) -> EpisodeInfo? {
        guard let url = URL(string: "https://api.thetvdb.com/episodes/" + String(episodeID)),
            let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(EpisodesInfoWrapper.self, from: data)
            else { return nil }

        return result.data
    }

}
