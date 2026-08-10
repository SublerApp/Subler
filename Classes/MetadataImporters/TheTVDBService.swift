//
//  TheTVDBService.swift
//  Subler
//
//  Created by Damiano Galassi on 15/06/2017.
//

import Foundation
import MP42Foundation

struct TVDBLanguage : Codable {
    let id: String
    let name: String
    let nativeName: String
    let shortCode: String?
}

public struct TVDBAlias : Codable {
    public let language: String
    public let name: String
}

public class TVDBArtworkType : Codable {
    public let id: Int64
    public let name: String
    public let imageFormat: String
    public let width: Int64
    public let height: Int64
    public let thumbHeight: Int64
    public let thumbWidth: Int64
    public let recordType: String
}

public class TVDBArtworkStatus : Codable {
    let id: Int64
    let name: String?
}

public class TVDBArtworkExtendedRecord : Codable {
    public let episodeId: Int?
    public let height: Int64
    public let id: Int64
    public let image: String
    public let includesText: Bool
    public let language: String?
    public let movieId: Int?
    public let networkId: Int?
    public let peopleId: Int?
    public let score: Double
    public let seasonId: Int?
    public let seriesId: Int?
    public let seriesPeopleId: Int?
    public let status: TVDBArtworkStatus
//    public let tagOptions: TVDBTagOptions
    public let thumbnail: String
    public let thumbnailHeight: Int64
    public let thumbnailWidth: Int64
    public let type: Int64
    public let updatedAt: Int64
}

public class TVDBGenreBaseRecord : Codable {
    public let id: Int64
    public let name: String
    public let slug: String
}

public struct TVDBCharacter : Codable {
    public let aliases: [TVDBAlias]?
//    public let episode: TVDBRecordInfo
    public let episodeId: Int?
    public let id: Int
    public let image: String?
    public let isFeatured: Bool?
    public let movieId: Int?
    public let name: String?
    public let nameTranslations: [String]?
    public let overviewTranslations: [String]?
    public let peopleId: Int
    public let personImgURL: String?
    public let peopleType: String
    public let seriesId: Int
//    public let series: TVDBRecordInfo
    public let sort: Int
//    public let tagOptions: TVDBTagOptions
    public let type: Int
    public let url: String
    public let personName: String
}

public struct TVDBParentCompany : Codable {
    public let id: Int?
    public let name: String?
}

public struct TVDBCompany : Codable {
    public let activeDate: String?
    public let aliases: [TVDBAlias]
    public let country: String?
    public let id: Int64
    public let inactiveDate: String?
    public let name: String
    public let nameTranslations: [String]
    public let overviewTranslations: [String]
    public let primaryCompanyType: Int64
    public let slug: String
    public let parentCompany: TVDBParentCompany?
//    public let tagOptions: TVDBTagOptions
}

public struct TVDBContentRating : Codable {
    public let id: Int64
    public let name: String
    public let description: String
    public let country: String
    public let contentType: String
    public let order: Int
    public let fullName: String?
}

public struct TVDBRemoteId : Codable {
    public let id: String
    public let type: Int64
    public let sourceName: String
}

public struct TVDBTranslation : Codable {
    public let aliases: [String]?
    public let isAlias: Bool?
    public let isPrimary: Bool?
    public let language: String
    public let name: String?
    public let overview: String?
    public let tagline: String?
}

public struct TVDBTranslationExtended : Codable {
    public let nameTranslations: [TVDBTranslation]?
    public let overviewTranslations: [TVDBTranslation]?
    public let alias: [String]?
}

public class TVDBStatus : Codable {
    public let id: Int64?
    public let keepUpdated: Bool
    public let name: String
    public let recordType: String
}

public struct TVDBSeriesSearchResult : Codable {
    public let aliases: [String]?
    public let thumbnail: String?
    public let first_air_time: String?
    public let tvdb_id: String
    public let network: String?
    public let overview: String?
    public let name: String?
    public let status: String
}

public struct TVDBEpisodeBaseRecord : Codable {
    public let absoluteNumber: Double?
    public let aired: String?
    public let airsBeforeEpisode: Int?
    public let airsBeforeSeason: Int?
    public let finaleType: String?
    public let id: Int
    public let image: String?
    public let imageType: Int?
    public let isMovie: Int
    public let lastUpdated: String
    public let name: String?
    public let nameTranslations: [String]?
    public let number: Int
    public let overview: String?
    public let overviewTranslations: [String]?
    public let runtime: Int?
    public let seasonNumber: Int
//    public let seasons: []?
    public let seriesId: Int
    public let year: String?
}

public struct TVDBEpisodeExtendedRecord : Codable {
    public let aired: String?
    public let airsAfterSeason: Int?
    public let airsBeforeEpisode: Int?
    public let airsBeforeSeason: Int?
//    public let awards: [TVDBAwardBaseRecord]
    public let characters: [TVDBCharacter]?
    public let companies: [TVDBCompany]
    public let contentRatings: [TVDBContentRating]
    public let finaleType: String?
    public let id: Int64
    public let image: String?
    public let imageType: Int?
    public let isMovie: Int64
    public let lastUpdated: String
    public let linkedMovie: Int?
    public let name: String
    public let nameTranslations: [String]
    public let networks: [TVDBCompany]?
//    public let nominations: [TVDBAwardNomineeBaseRecorde]
    public let number: Int
    public let overview: String?
    public let overviewTranslations: [String]?
    public let productionCode: String?
    public let remoteIds: [TVDBRemoteId]
    public let runtime: Int?
    public let seasonNumber: Int
//    public let season: []
    public let seriesId: Int64
    public let studios: [TVDBCompany]?
//    public let tagOptions: [TVDBTagOption]
//    public let trailers: [TVDBTrailer]
    public let translations: TVDBTranslationExtended?
    public let year: String
}

public struct TVDBSeriesBaseRecord : Codable {
    public let aliases: [TVDBAlias]
    public let averageRuntime: Int?
    public let defaultSeasonType: Int64
    public let episodes: [TVDBEpisodeBaseRecord]?
    public let firstAired: String
    public let id: Int
    public let image: String
    public let isOrderRandomized: Bool
    public let lastAired: String
    public let lastUpdated: String
    public let name: String
    public let nameTranslations: [String]
    public let nextAired: String
    public let originalCountry: String
    public let originalLanguage: String
    public let overview: String?
    public let overviewTranslations: [String]
    public let score: Int
    public let slug: String
//    public let status: Status
    public let year: String?
}

public struct TVDBSeriesExtendedRecord : Codable {
    public let abbreviation: String?
//    public let airsDays: TVDBSeriesAirsDays
    public let aliases: [TVDBAlias]
    public let artworks: [TVDBArtworkExtendedRecord]
    public let averageRuntime: Int?
    public let characters: [TVDBCharacter]?
    public let contentRatings: [TVDBContentRating]
    public let country: String?
    public let defaultSeasonType: Int64
    public let episodes: [TVDBEpisodeBaseRecord]?
    public let firstAired: String
//    public let lists: TVDBList
    public let genres: [TVDBGenreBaseRecord]
    public let id: Int
    public let image: String?
    public let isOrderRandomized: Bool
    public let lastAired: String
    public let lastUpdated: String
    public let name: String
    public let nameTranslations: [String]
    public let companies: [TVDBCompany]
    public let nextAired: String
    public let originalCountry: String
    public let originalLanguage: String
    public let originalNetwork: TVDBCompany?
    public let overview: String?
    public let latestNetwork: TVDBCompany?
    public let overviewTranslations: [String]
    public let remoteIds: [TVDBRemoteId]
    public let score: Double
//    public let seasons: [TVDBSeasonBaseRecord]
//    public let seasons: [TVDBSeasonType]
    public let status: TVDBStatus
    public let slug: String
//    public let status: Status
//    public let tags: [TVDBTagOptions]
//    public let trailers: [TVDBTrailer]
    public let translations: TVDBTranslationExtended?
    public let year: String
}

final public class TheTVDBService {

    public static let sharedInstance = TheTVDBService()

    private let queue: DispatchQueue
    private let tokenQueue: DispatchQueue

    private static let apiKey = "7bba6aca-a2c7-42d1-9c34-ed84bb44dfc6"
    private static let basePath = "https://api4.thetvdb.com/v4/"

    private var savedLanguages: [String]

    public var languages: [String] {
        get {
            return queue.sync {
                let now = Date.timeIntervalSinceReferenceDate
                let timestamp = UserDefaults.standard.double(forKey: "SBTheTVBDv4LanguagesArrayTimestamp")
                if let languagesArray = UserDefaults.standard.object(forKey: "SBTheTVBDv4LanguagesArray") as? [String], languagesArray.isEmpty == false,
                   timestamp + 60 * 60 * 24 * 30 > Date.timeIntervalSinceReferenceDate {
                    savedLanguages = languagesArray
                } else {
                    savedLanguages = fetchLanguages()
                    UserDefaults.standard.set(savedLanguages, forKey: "SBTheTVBDv4LanguagesArray")
                    UserDefaults.standard.set(now, forKey: "SBTheTVBDv4LanguagesArrayTimestamp")
                }
                return savedLanguages
            }
        }
    }

    private struct Token {
        let key: String
        let timestamp: TimeInterval
    }

    private static let tokenKey = "SBTheTVBDv4Token"
    private static let tokenTimestampKey = "SBTheTVBDv4TokenTimestamp"

    private var savedToken: Token?

    private var token: Token? {
        get {
            return tokenQueue.sync {
                if let result = savedToken, result.timestamp + 60 * 60 * 4 > Date.timeIntervalSinceReferenceDate  {
                    return result
                }
                else if let result = login() {
                    UserDefaults.standard.set(result.key, forKey: TheTVDBService.tokenKey)
                    UserDefaults.standard.set(result.timestamp, forKey: TheTVDBService.tokenTimestampKey)
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
        savedLanguages = []

        if let tokenKey = UserDefaults.standard.string(forKey: TheTVDBService.tokenKey) {
            let timestamp = UserDefaults.standard.double(forKey: TheTVDBService.tokenTimestampKey)
            if timestamp + 60 * 60 * 4 > Date.timeIntervalSinceReferenceDate {
                savedToken = Token(key: tokenKey, timestamp: timestamp)
            }
        }
    }

    private struct Wrapper<T> : Codable where T : Codable {
        let data: T
        let status: String
    }

    // MARK: - Login

    private func login() -> Token? {
        struct ApiKey : Codable {
            let apikey: String
        }

        struct TokenWrapper: Codable {
            let token: String
        }

        guard let apikey = try? JSONEncoder().encode(ApiKey(apikey: TheTVDBService.apiKey)) else { return nil }
        guard let url = URL(string: TheTVDBService.basePath + "login") else { return nil }

        let header = ["Content-Type" : "application/json"]

        guard let response = URLSession.data(from: url,
                                             httpMethod: "POST",
                                             httpBody:apikey,
                                             header: header) else { return nil }

        do {
            let responseToken = try JSONDecoder().decode(Wrapper<TokenWrapper>.self, from: response)
            return Token(key: responseToken.data.token, timestamp: Date.timeIntervalSinceReferenceDate)
        } catch {
            print("\(error)")
        }

        return nil
    }

    // MARK: - Languages

    private func fetchLanguages() -> [String] {

        guard let url = URL(string: "\(TheTVDBService.basePath)languages"),
            let result = sendJSONRequest(url: url, type: Wrapper<[TVDBLanguage]>.self)
            else { return [] }

        return result.data.map { $0.id }
    }

    private var artworkTypes: [TVDBArtworkType]?

    public func fetchArtworkTypes() -> [TVDBArtworkType] {
        if let artworkTypes {
            return artworkTypes
        } else {
            guard let url = URL(string: "\(TheTVDBService.basePath)artwork/types"),
                  let result = sendJSONRequest(url: url, type: Wrapper<[TVDBArtworkType]>.self)
            else { return [] }

            artworkTypes = result.data
            return result.data
        }
    }

    // MARK: - Data request

    private func sendRequest(url: URL) -> Data? {
        guard let token = self.token else { return nil }

        let header = ["Authorization": "Bearer \(token.key)",
                      "accept" : "application/json"]

        return URLSession.data(from: url, header: header)
    }

    private func sendJSONRequest<T>(url: URL, type: T.Type) -> T? where T : Decodable {
        guard let data = sendRequest(url: url) else { return nil }

//        let response = String(data: data, encoding: .utf8)
//        if let response {
//            print(response)
//        }

        do {
            let result = try JSONDecoder().decode(type, from: data)
            return result
        } catch {
            print(error)
        }

        return nil
    }

    // MARK: - Service calls
    
    public func fetch(series: String, language: String) -> [TVDBSeriesSearchResult] {
        // Remove + because it breaks search
        let encodedName = series.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "*", with: "-").urlEncoded()

        guard let url = URL(string: "\(TheTVDBService.basePath)search?query=\(encodedName)&type=series&language=eng"),
            let result = sendJSONRequest(url: url, type: Wrapper<[TVDBSeriesSearchResult]>.self)
            else { return [] }

        return result.data
    }

    public func fetch(seriesInfo seriesID: String, language: String) -> TVDBSeriesExtendedRecord? {
        guard let url = URL(string: "\(TheTVDBService.basePath)series/\(seriesID)/extended"),
            let result = sendJSONRequest(url: url, type: Wrapper<TVDBSeriesExtendedRecord>.self)
            else { return nil }

        return result.data
    }

    public func fetch(seriesTranslation seriesID: String, language: String) -> TVDBTranslation? {
        guard let url = URL(string: "\(TheTVDBService.basePath)series/\(seriesID)/translations/\(language)"),
            let result = sendJSONRequest(url: url, type: Wrapper<TVDBTranslation>.self)
            else { return nil }

        return result.data
    }

    private func episodesURL(seriesID: Int, season: Int?, episode: Int?, language: String) -> URL? {
        switch (season, episode) {
        case let (season?, episode?):
            return URL(string: "\(TheTVDBService.basePath)series/\(seriesID)/episodes/default/\(language)?page=0&season=\(season)&episodeNumber=\(episode)")
        case let (season?, _):
            return URL(string: "\(TheTVDBService.basePath)series/\(seriesID)/episodes/default/\(language)?page=0&season=\(season)")
        default:
            return URL(string: "\(TheTVDBService.basePath)series/\(seriesID)/episodes/default/\(language)?page=0")
        }
    }
    
    public func fetch(episodesForSeriesID seriesID: Int, season: Int?, episode: Int?, language: String) -> [TVDBEpisodeBaseRecord] {
        guard let url = episodesURL(seriesID: seriesID, season: season, episode: episode, language: language),
            let result = sendJSONRequest(url: url, type: Wrapper<TVDBSeriesBaseRecord>.self)
            else { return [] }

        return result.data.episodes ?? []
    }

    public func fetch(episodeInfo episodeID: Int, language: String) -> TVDBEpisodeExtendedRecord? {
        guard let url = URL(string: "\(TheTVDBService.basePath)episodes/\(episodeID)/extended"),
            let result = sendJSONRequest(url: url, type: Wrapper<TVDBEpisodeExtendedRecord>.self)
            else { return nil }

        return result.data
    }

    public func fetch(episodesTranslation episodeID: Int, language: String) -> TVDBTranslation? {
        guard let url = URL(string: "\(TheTVDBService.basePath)episodes/\(episodeID)/translations/\(language)"),
            let result = sendJSONRequest(url: url, type: Wrapper<TVDBTranslation>.self)
            else { return nil }

        return result.data
    }

}
