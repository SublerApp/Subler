//
//  ChapterDB.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Foundation
import MP42Foundation

public struct ChapterDB : ChapterService {

    private let basePath = "https://chapterdb.plex.tv/chapters/"

    public func search(title: String, duration: UInt64) -> [ChapterResult] {

        guard let url = URL(string: "\(basePath)search?title=\(title.urlEncoded())"),
            let data = fetch(url: url)
            else { return [] }

        let delta: Int64 = 20000

        let parsed = parse(data: data)
        let almostMovieDuration = parsed.filter { $0.duration < (Int64(duration) + delta) && $0.duration > (Int64(duration) - delta) }
        let lessThanMovieDuration = parsed.filter { if let timestamp = $0.chapters.last?.timestamp, timestamp < duration { return true} else { return false} }

        if duration > 0 && almostMovieDuration.count > 0 { return almostMovieDuration }
        else if lessThanMovieDuration.count > 0 { return lessThanMovieDuration }
        else { return parsed }
    }

    private func fetchDetails(id: UInt64) -> [Chapter]? {
        guard let url = URL(string: "\(basePath)\(id)"),
            let data = fetch(url: url)
            else { return [] }

        let parsed = fullParse(data: data)
        return parsed.first?.chapters
    }

    private func fetch(url: URL) -> Data? {
        let header = ["ApiKey": "7WXY7WRDFBT33L1UX7OO"]
        return URLSession.data(from: url, header: header)
    }

    private func title(node: XMLNode) -> String? {
        guard let nodes = try? node.nodes(forXPath: "./*:title") else { return nil }
        return nodes.first?.stringValue
    }

    private func confirmations(node: XMLNode) -> UInt? {
        guard let nodes = try? node.nodes(forXPath: "./@confirmations"),
            let confirmations = nodes.first?.stringValue else { return nil }
        return UInt(confirmations)
    }

    private func duration(node: XMLNode) -> UInt64? {
        guard let nodes = try? node.nodes(forXPath: "./*:source/*:duration"),
            let duration = nodes.first?.stringValue else { return nil }
        return TimeFromString(duration, 1000)
    }

    private func setID(node: XMLNode) -> UInt64? {
        guard let nodes = try? node.nodes(forXPath: "./*:ref/*:chapterSetId"),
            let setID = nodes.first?.stringValue else { return nil }
        return UInt64(setID)
    }

    private func parse(node: XMLNode) -> ChapterResult? {
        guard let title = title(node: node),
            let confirmations = confirmations(node: node),
            let duration = duration(node: node),
            let setID = setID(node: node) else { return nil }

        if let chapters = fetchDetails(id: setID) {
            return ChapterResult(title: title, duration: duration, id: setID, confimations: confirmations, chapters: chapters)
        } else {
            return nil
        }
    }

    private func parse(data: Data) -> [ChapterResult] {
        guard let document = try? XMLDocument(data: data, options: []),
            let children = try? document.nodes(forXPath: "//*:chapterInfo") else { return [] }

        return children.compactMap { parse(node: $0) }
    }

    private func fullParse(node: XMLNode) -> ChapterResult? {
        guard let title = title(node: node),
            let confirmations = confirmations(node: node),
            let duration = duration(node: node),
            let setID = setID(node: node),
            let times = try? node.nodes(forXPath: "./*:chapters/*:chapter/@time"),
            let names = try? node.nodes(forXPath: "./*:chapters/*:chapter/@name") else { return nil }

        var currentTime: UInt64 = 0
        var chapters: [Chapter] = []

        for (time, name) in zip(times.compactMap { $0.stringValue }, names.compactMap { $0.stringValue }) {
            let timestamp = TimeFromString(time, 1000)

            if timestamp < currentTime {
                break;
            }
            else {
                currentTime = timestamp
            }

            let chapter = Chapter(name: name, timestamp: timestamp)
            chapters.append(chapter)
        }

        if chapters.isEmpty == false {
            let result = ChapterResult(title: title, duration: duration, id: setID, confimations: confirmations, chapters: chapters)
            return result
        }

        return nil
    }

    private func fullParse(data: Data) -> [ChapterResult] {
        guard let document = try? XMLDocument(data: data, options: []),
            let children = try? document.nodes(forXPath: "//*:chapterInfo") else { return [] }

        return children.compactMap { fullParse(node: $0) }
    }

}
