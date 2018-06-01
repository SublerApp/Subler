//
//  SquaredTVArt.swift
//  Subler
//
//  Created by Damiano Galassi on 07/08/2017.
//

import Foundation

private struct PhotoSize : Codable {
    let height: Int
    let width: Int
    let url: URL
}

private struct Photo : Codable {
    let original_size: PhotoSize
    let alt_sizes: [PhotoSize]
    let caption: String?

    func toRemoteImage() -> Artwork {
        let thumbURL = alt_sizes.filter { $0.width > 200 && $0.width < 400 }.first?.url ?? original_size.url
        return Artwork(url: original_size.url, thumbURL: thumbURL, service: "Squared TV Art", type: .square)
    }
}

private struct Post : Codable {
    let tags: [String]
    let photos: [Photo]
}

private struct Response : Codable {
    let posts: [Post]
}

private struct Meta : Codable {
    let status: Int
    let msg: String
}

private struct SearchResult : Codable {
    let meta: Meta;
    let response: Response;
}

private func sendRequest(url: URL) -> Data? {
    let header = ["Content-Type" : "application/json",
                  "Accept" : "application/json;charset=utf-8"]

    return URLSession.data(from: url, header: header)
}

private func sendJSONRequest<T>(url: URL, type: T.Type) -> T? where T : Decodable {
    guard let data = sendRequest(url: url) , let result = try? JSONDecoder().decode(type, from: data)
        else { return nil }

    return result
}

struct SquaredTVArt {

    private let basePathAPI = "https://api.tumblr.com/v2/blog/squaredtvart.tumblr.com/"

    public var name: String {
        return "Squared TV Art"
    }

    private func search(byTVShow tvShow: String) -> [Post] {
        let encodedName = tvShow.urlEncoded()

        guard let url = URL(string: basePathAPI + "posts/photo?tag=" + encodedName + "&api_key=ZbYXwG2CtSECdqttl7rUU076pj5fqhMsV84BwnhK2GSMaJXutJ"),
            let result = sendJSONRequest(url: url, type: SearchResult.self)
            else { return [] }

        return result.response.posts
    }

    private func search(byTVShow tvShow: String, season: Int) -> [Post] {
        let posts = search(byTVShow: tvShow)
        return posts.filter { $0.tags.contains("Season \(season)")}
    }

    private func search(byID theTVDBSeriesId: Int) -> [Post] {
        guard let url = URL(string: basePathAPI + "posts/photo?tag=thetvdb+series+" + String(theTVDBSeriesId) + "&api_key=ZbYXwG2CtSECdqttl7rUU076pj5fqhMsV84BwnhK2GSMaJXutJ"),
            let result = sendJSONRequest(url: url, type: SearchResult.self)
            else { return [] }

        return result.response.posts
    }

    private func search(byID theTVDBSeriesId: Int, season: Int) -> [Post] {
        let posts = search(byID: theTVDBSeriesId)
        return posts.filter { $0.tags.contains("Season \(season)")}
    }

    public func search(tvShow: String, theTVDBSeriesId: Int, season: Int) -> [Artwork] {
        let idSearch = search(byID: theTVDBSeriesId, season: season)

        if idSearch.isEmpty == false {
            return idSearch.flatMap { $0.photos.map { $0.toRemoteImage() } }
        } else {
            let tvShowSearch = search(byTVShow: tvShow, season: season)
            return tvShowSearch.flatMap { $0.photos.map { $0.toRemoteImage() } }
        }
    }

}
