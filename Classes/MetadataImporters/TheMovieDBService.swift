//
//  TheMovieDBService.swift
//  Subler
//
//  Created by Damiano Galassi on 27/06/2017.
//

import Foundation

public struct TMDBSearchResult : Codable {
    let poster_path: String?
    let adult: Bool?
    let overview: String?
    let release_date: String?
    let genre_ids: [Int]?

    let id: Int

    let original_title: String?
    let original_language: String?
    let title: String?
    let backdrop_path: String?
    let popularity: Double?
    let vote_count: Int?
    let video: Bool?
    let vote_average: Double?
}

public struct TMDBTuple : Codable {
    let id: Int?
    let name: String?
}

public struct TMDBImage : Codable {
    let aspect_ration: Double?
    let file_path: String
    let height: Int?
    let iso_639_1: String?
    let vote_average: Double?
    let vote_count: Int?
    let width: Int?
}

public struct TMDBImages : Codable {
    let backdrops: [TMDBImage]
    let posters: [TMDBImage]
}

public struct TMDBCast : Codable {
    let cast_id: Int?
    let character: String?
    let credit_id: String?
    let gender: Int?
    let id: Int?
    let name: String
    let order: Int?
    let profile_path: String?
}

public struct TMDBCrew : Codable {
    let credit_id: String?
    let department: String?
    let gender: Int?
    let id: Int?
    let job: String
    let name: String
    let profile_path: String?
}
public struct TMDBCasts : Codable {
    let cast: [TMDBCast]
    let crew: [TMDBCrew]
}

public struct TMDBRelease : Codable {
    let certification: String
    let iso_3166_1: String
    let release_date: String?
}

public struct TMDBReleases: Codable {
    let countries: [TMDBRelease]
}

public struct TMDBMovie : Codable {
    let genres: [TMDBTuple]?
    let id: Int?
    let overview: String?
    let release_date: String?
    
    let production_companies: [TMDBTuple]?
    
    let tagline: String?
    let title: String?
    
    let casts: TMDBCasts?
    let images: TMDBImages?
    let backdrop_path: String?
    let poster_path: String?

    let releases: TMDBReleases?
}

public struct TMDBImageConfiguration : Codable {
    let base_url: String?
    let secure_base_url: String?
    let backdrop_sizes: [String]
    let logo_sizes: [String]
    let poster_sizes: [String]
    let profile_sizes: [String]
    let still_sizes: [String]
}

public struct TMDBConfiguration : Codable {
    let change_keys: [String]?
    let images: TMDBImageConfiguration?
}

final public class TheMovieDBService {

    public static let sharedInstance = TheMovieDBService()
    
    private let basePath = "https://api.themoviedb.org/3/"
    private let key = "b0073bafb08b4f68df101eb2325f27dc"

    private init() {}

    private struct Wrapper<T> : Codable where T : Codable {
        let results: T
    }

    // MARK: - Data request

    private func sendRequest(url: URL, language: String) -> Data? {
        let header = ["Content-Type" : "application/json",
                      "Accept" : "application/json;charset=utf-8",
                      "Accept-Language" : language]

        return SBMetadataHelper.downloadData(from: url, httpMethod: "GET", httpBody: nil, headerOptions: header, cachePolicy: .default)
    }

    private func sendJSONRequest<T>(url: URL, language: String, type: T.Type) -> T? where T : Decodable {
        guard let data = sendRequest(url: url, language: language),
            let result = try? JSONDecoder().decode(type, from: data)
            else { return nil }

        return result
    }

    // MARK: - Service calls

    public func search(movie: String, language: String) -> [TMDBSearchResult]  {
        let encodedName = SBMetadataHelper.urlEncoded(movie)

        guard let url = URL(string: basePath + "search/movie?api_key=" + key + "&query=" + encodedName + "&language=" + language),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<[TMDBSearchResult]>.self)
            else { return [] }

        return result.results
    }

    public func fetch(movieID: Int, language: String) -> TMDBMovie?  {
        guard let url = URL(string: basePath + "movie/" + String(movieID) + "?api_key=" + key + "&language=" + language + "&append_to_response=casts,releases,images"),
            let result = sendJSONRequest(url: url, language: language, type: TMDBMovie.self)
            else { return nil }

        return result
    }

    public func fetchConfiguration() -> TMDBConfiguration?  {
        guard let url = URL(string: basePath + "configuration?api_key=" + key),
            let result = sendJSONRequest(url: url, language: "en", type: TMDBConfiguration.self)
            else { return nil }

        return result
    }
}
