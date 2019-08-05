//
//  SquaredTVArt.swift
//  Subler
//
//  Created by Damiano Galassi on 07/08/2017.
//

import Foundation

struct SquaredTVArt {

    public var name: String {
        return "Squared TV Art"
    }

    public func search(tvShow: String, theTVDBSeriesId: Int, season: Int) -> [Artwork] {
        let htmlResults = SquaredTVArtHTMLScraper().search(tvShow: tvShow, theTVDBSeriesId: theTVDBSeriesId, season: season)

        if htmlResults.isEmpty == false {
            return htmlResults
        }
        else {
            return SquaredTVArtJsonApi().search(tvShow: tvShow, theTVDBSeriesId: theTVDBSeriesId, season: season)
        }
    }
}

private struct SquaredTVArtJsonApi {

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

    private let basePathAPI = "https://api.tumblr.com/v2/blog/squaredtvart.tumblr.com/"

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

private struct SquaredTVArtHTMLScraper {

    private let basePath = "https://squaredtvart.tumblr.com/"

    private struct SquaredTVArtwork {
        let thumbURL: URL
        let tvShow: String
        let thetvdbSeriesID: Int
        let season: Int
        let thetvdbSeasonID: Int

        var url: URL {
            return URL(string: thumbURL.absoluteString.replacingOccurrences(of: "_250.jpg", with: "_1280.jpg")) ?? thumbURL
        }

        func toRemoteImage() -> Artwork {
            return Artwork(url: url, thumbURL: thumbURL, service: "Squared TV Art", type: .square)
        }
    }

    public func search(tvShow: String) -> [Artwork] {
        let searchTerm = tvShow.urlEncoded()
        guard let url = URL(string: "\(basePath)search/\(searchTerm)") else { return [] }

        let mapped = search(url: url).map { $0.toRemoteImage() }
        return mapped
    }

    public func search(tvShow: String, season: Int) -> [Artwork] {
        let searchTerm = "\(tvShow) Season \(season)".urlEncoded()
        guard let url = URL(string: "\(basePath)search/\(searchTerm)") else { return [] }

        let mapped = search(url: url).filter { $0.season == season } .map { $0.toRemoteImage() }
        return mapped
    }

    public func search(theTVDBSeriesId: Int, season: Int) -> [Artwork] {
        let searchTerm = "\(theTVDBSeriesId) Season \(season)".urlEncoded()
        guard let url = URL(string: "\(basePath)search/\(searchTerm)") else { return [] }

        let mapped = search(url: url).filter { $0.season == season } .map { $0.toRemoteImage() }
        return mapped
    }

    public func search(tvShow: String, theTVDBSeriesId: Int, season: Int) -> [Artwork] {
        let tvdbIdSearch = search(theTVDBSeriesId: theTVDBSeriesId, season: season)

        if tvdbIdSearch.isEmpty == false {
            return tvdbIdSearch
        }

        let tvShowSearch = search(tvShow: tvShow, season: season)
        return tvShowSearch
    }

    private func search(url: URL) -> [SquaredTVArtwork] {
        guard let data = URLSession.data(from: url),
            let xml = try? XMLDocument(data: data, options: .documentTidyHTML)
            else { return [] }

        return parse(xml: xml)
    }

    private func thumbURL(xml: XMLDocument) -> URL? {
        guard let nodes = try? xml.nodes(forXPath: "//img") else { return nil }
        if let node = nodes.first, node.kind == .element,
            let element = node as? XMLElement,
            let value = element.attribute(forName: "src")?.stringValue {
            return URL(string: value)
        }
        return nil
    }

    private func completeName(xml: XMLDocument) -> String? {
        guard let nodes = try? xml.nodes(forXPath: "//img") else { return nil }
        if let node = nodes.first, node.kind == .element, let element = node as? XMLElement {
            return element.attribute(forName: "alt")?.stringValue
        }
        return nil
    }

    private func parse(info: [Substring], type: String) -> Int? {
        let filtered = info.filter { $0.hasPrefix(type) }
        if let seriesID = filtered.first {
            return Int(String(seriesID).replacingOccurrences(of: type, with: ""))
        }
        return nil
    }

    private func parseString(info: [Substring], type: String) -> String? {
        let filtered = info.filter { $0.hasPrefix(type) }
        if let seriesID = filtered.first {
            return String(seriesID).replacingOccurrences(of: type, with: "")
        }
        return nil
    }

    private func parse(xml: XMLDocument) -> [SquaredTVArtwork] {
        guard let nodes = try? xml.nodes(forXPath: "//div[starts-with(@class,'Post ')]") else { return [] }

        return nodes.compactMap { (node) -> SquaredTVArtwork? in
            if let subXml = try? XMLDocument(xmlString: node.xmlString, options: []),
                let name = completeName(xml: subXml),
                let url = thumbURL(xml: subXml),
                node.kind == .element, let element = node as? XMLElement,
                let info = element.attribute(forName: "class")?.stringValue?.split(separator: " "),
                let seriesID = parse(info: info, type: "thetvdb_series_"),
                let seasonID = parse(info: info, type: "thetvdb_season_"),
                //let imdbID = parseString(info: info, type: "imdb_series"),
                let season = parse(info: info, type: "season_") {
                return SquaredTVArtwork(thumbURL: url, tvShow: name, thetvdbSeriesID: seriesID, season: season, thetvdbSeasonID: seasonID)
            }
            return nil
        }
    }
}

