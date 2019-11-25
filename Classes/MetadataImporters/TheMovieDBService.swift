//
//  TheMovieDBService.swift
//  Subler
//
//  Created by Damiano Galassi on 27/06/2017.
//

import Foundation

public struct TMDBMovieSearchResult : Codable {
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
    // let vote_count: Int?
    let video: Bool?
    // let vote_average: Double?
}

public struct TMDBTVSearchResult : Codable {
    let poster_path: String?
    let popularity: Double?
    let id: Int
    let backdrop_path: String?
    // let vote_average: Double?
    let overview: String?
    let first_air_date: String?
    let origin_country: [String]?
    let genre_ids: [Int]?
    let original_language: String?
    // let vote_count: Int?
    let name: String?
    let original_name: String?
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
    // let vote_average: Double?
    // let vote_count: Int?
    let width: Int?
}

public struct TMDBImages : Codable {
    let backdrops: [TMDBImage]?
    let posters: [TMDBImage]?
}

public struct TMDBEpisodeImages : Codable {
    let stills: [TMDBImage]?
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

public struct TMDBEpisode : Codable {
    let air_date: String?
    let crew: [TMDBCrew]?
    let episode_number: Int?
    let guest_stars: [TMDBCast]?
    let name: String?
    let overview: String?
    let id: Int?
    let production_code: String?
    let season_number: Int?
    let still_path: String?
    //let vote_average: Double?
    //let vote_count: Int?
}

public struct TMDBSeason : Codable {
    let air_date: String?
    let episode_count: Int?
    let id: Int?
    let poster_path: String?
    let season_number: Int?
    let overview: String?
    let name: String?
    let episodes: [TMDBEpisode]?
}

public struct TMDBContentRating : Codable {
    let iso_3166_1: String?
    let rating: String?
}

public struct TMDBContentRatingWrapper : Codable {
    let results: [TMDBContentRating]?
}

public struct TMDBExternalIDs : Codable {
    let imdb_id: String?
    let tvdb_id: Int?
}

public struct TMDBSeries : Codable {
    let backdrop_path: String?
    let created_by: [TMDBTuple]?
    let episode_run_time: [Int]?
    let first_air_date: String?
    let genres: [TMDBTuple]?
    let homepage: String?
    let id: Int?
    let in_production: Bool?
    let languages: [String]?
    let last_air_date: String?
    let name: String?
    let networks: [TMDBTuple]?
    let number_of_episodes: Int?
    let number_of_seasons: Int?
    let origin_country: [String]?
    let original_language: String?
    let original_name: String?
    let overview: String?
    let popularity: Double?
    let poster_path: String?
    let production_companies: [TMDBTuple]?
    let seasons: [TMDBSeason]?
    let status: String?
    let type: String?
//    let vote_average: Double?
    let vote_count: Int?

    let content_ratings: TMDBContentRatingWrapper?
    let credits: TMDBCasts?
    let images: TMDBImages?

    let external_ids: TMDBExternalIDs?
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
        let page: Int?
        let total_results: Int?
        let total_pages: Int?
    }

    // MARK: - Data request

    private func sendRequest(url: URL, language: String) -> (Data?, URLResponse?) {
        let header = ["Content-Type" : "application/json",
                      "Accept" : "application/json;charset=utf-8",
                      "Accept-Language" : language]

        return URLSession.dataAndResponse(from: url, header: header)
    }

    private func sendJSONRequest<T>(url: URL, language: String, type: T.Type) -> T? where T : Decodable {
        let (data, response) = sendRequest(url: url, language: language)

        if let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 429,
            let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? String {
            let retryTime = (Int(retryAfter) ?? 1) * 1000000
            usleep(useconds_t(retryTime))
            return sendJSONRequest(url: url, language: language, type: type)
        }

        guard let data1 = data, let result = try? JSONDecoder().decode(type, from: data1)
            else { return nil }

        return result
    }

    // MARK: - Service calls

    private func search(movie: String, language: String, page: Int) -> Wrapper<[TMDBMovieSearchResult]>? {
        let encodedName = movie.urlEncoded()

        guard let url = URL(string: basePath + "search/movie?api_key=" + key + "&query=" + encodedName + "&language=" + language + "&page=" + String(page)),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<[TMDBMovieSearchResult]>.self)
            else { return nil }

        return result
    }

    public func search(movie: String, language: String) -> [TMDBMovieSearchResult]  {
        guard let result = search(movie: movie, language: language, page: 1) else { return [] }

        if let totalPages = result.total_pages, totalPages > 1 {
            let pages = totalPages > 20 ? 2...20 : 2...totalPages
            let additionalResult = Array(pages).compactMap { search(movie: movie, language: language, page: $0)?.results }
            return result.results + additionalResult.joined();
        } else {
            return result.results
        }
    }

    public func fetch(movieID: Int, language: String) -> TMDBMovie?  {
        guard let url = URL(string: basePath + "movie/" + String(movieID) + "?api_key=" + key + "&language=" + language + "&append_to_response=casts,releases,images"),
            let result = sendJSONRequest(url: url, language: language, type: TMDBMovie.self)
            else { return nil }

        return result
    }

    public func search(series: String, language: String) -> [TMDBTVSearchResult] {
        let encodedName = series.urlEncoded()

        guard let url = URL(string: basePath + "search/tv?api_key=" + key + "&query=" + encodedName + "&language=" + language),
            let result = sendJSONRequest(url: url, language: language, type: Wrapper<[TMDBTVSearchResult]>.self)
            else { return [] }

        return result.results
    }

    public func fetch(seriesID: Int, language: String) -> TMDBSeries?  {
        guard let url = URL(string: basePath + "tv/" + String(seriesID) + "?api_key=" + key + "&language=" + language + "&append_to_response=content_ratings,credits,images,external_ids"),
            let result = sendJSONRequest(url: url, language: language, type: TMDBSeries.self)
            else { return nil }

        return result
    }

    private func episodesURL(seriesID: Int, season: Int?, episode: Int?, language: String) -> URL? {
        let basePostfix = "?api_key=" + key + "&language=" + language
        switch (season, episode) {
        case let (season?, episode?):
            return URL(string: "\(basePath)tv/\(seriesID)/season/\(season)/episode/\(episode)\(basePostfix)")
        case let (season?, _):
            return URL(string: "\(basePath)tv/\(seriesID)/season/\(season)\(basePostfix)")
        default:
            return URL(string: basePath + "tv/" + String(seriesID) +  "/season" + basePostfix)
        }
    }

    public func fetch(episodeForSeriesID seriesID: Int, season: Int?, episode: Int?, language: String) -> [TMDBEpisode] {
        guard let url = episodesURL(seriesID: seriesID, season: season, episode: episode, language: language) else { return [] }

        if episode != nil {
            guard let result = sendJSONRequest(url: url, language: language, type: TMDBEpisode.self) else { return [] }
            return [result]
        }
        else {
            guard let result = sendJSONRequest(url: url, language: language, type: TMDBSeason.self) else { return [] }
            return result.episodes ?? []
        }
    }

    public func fetch(imagesForSeriesID seriesID: Int, season: String, language: String) -> [TMDBImage] {
        guard let url = URL(string: basePath + "tv/" + String(seriesID) +  "/season/" + season + "/images?api_key=" + key + "&language=" + language),
            let result = sendJSONRequest(url: url, language: language, type: TMDBImages.self)
            else { return [] }

        return result.posters ?? []
    }

    public func fetch(imagesForSeriesID seriesID: Int, episodeNumber: Int, season: String, language: String) -> [TMDBImage] {
        guard let url = URL(string: basePath + "tv/" + String(seriesID) +  "/season/" + season + "/episode/" + String(episodeNumber) + "/images?api_key=" + key + "&language=" + language + "&include_image_language=en,null"),
            let result = sendJSONRequest(url: url, language: language, type: TMDBEpisodeImages.self)
            else { return [] }

        return result.stills ?? []
    }
    
    public func fetchConfiguration() -> TMDBConfiguration?  {
        guard let url = URL(string: basePath + "configuration?api_key=" + key),
            let result = sendJSONRequest(url: url, language: "en", type: TMDBConfiguration.self)
            else { return nil }

        return result
    }
}
