//
//  SquaredTVArt.swift
//  Subler
//
//  Created by Damiano Galassi on 07/08/2017.
//

import Foundation

struct SquaredTVArt {

    private let basePath = "https://squaredtvart.tumblr.com/"

    public var name: String {
        return "Squared TV Art"
    }

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

        return nodes.flatMap { (node) -> SquaredTVArtwork? in
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
