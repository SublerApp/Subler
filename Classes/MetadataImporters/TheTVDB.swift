//
//  TheTVDB.swift
//  Subler
//
//  Created by Damiano Galassi on 22/06/2017.
//

import Foundation

final public class TheTVDBSwift : SBMetadataImporter {

    private let session = TheTVDBSession.sharedInstance
    private let en = "en"

    override public var languageType: SBMetadataImporterLanguageType {
        get {
            return .ISO;
        }
    }

    override public var languages: [String] {
        get {
            return session.languages
        }
    }

    override public func searchTVSeries(_ seriesName: String, language: String) -> [String] {
        var results: Set<String> = Set()

        // search for series
        let series = session.fetch(series: seriesName, language: language)
        results.formUnion(series.map { $0.seriesName } )

        if language != en {
            let englishResults = searchTVSeries(seriesName, language: en)
            results.formUnion(englishResults)
        }

        return Array(results)
    }


    private func match(series: SeriesSearchResult, name: String) -> Bool {
        if series.seriesName == name {
            return true
        }

        for alias in series.aliases {
            if alias == name {
                return true
            }
        }

        return false
    }

    private func searchIDs(seriesName: String, language: String) -> [Int] {
        let series = session.fetch(series: seriesName, language: language)

        return series.filter { match(series: $0, name: seriesName) }.map { $0.id }
    }

    private func merge(episode: Episode, info: SeriesInfo, actors: [Actor]) -> SBMetadataResult {
        let result = SBMetadataResult()

        result.mediaKind = 10

        // TV Show Info
        result["TheTVDB Series ID"]                  = info.seriesId
        result[SBMetadataResultSeriesName]           = info.seriesName
        result[SBMetadataResultSeriesDescription]    = info.overview
        //result[SBMetadataResultGenre]                = info.genre       // TODO
        result[SBMetadataResultNetwork]              = info.network

        // Episode Info
        result["TheTVDB Episodes ID"]           = episode.id
        result[SBMetadataResultName]            = episode.episodeName
        result[SBMetadataResultReleaseDate]     = episode.firstAired
        result[SBMetadataResultDescription]     = episode.overview
        result[SBMetadataResultLongDescription] = episode.overview

        result[SBMetadataResultSeason]          = episode.airedSeason
        result[SBMetadataResultEpisodeID]       = episode.airedSeason

        result[SBMetadataResultEpisodeID]       = String(format: "%d%02d", episode.airedSeason, episode.airedEpisodeNumber)
        result[SBMetadataResultEpisodeNumber]   = episode.airedEpisodeNumber
        result[SBMetadataResultTrackNumber]     = episode.airedEpisodeNumber

        // Rating TODO

        // Actors TODO
        //result[SBMetadataResultCast] = [SBTheTVDB cleanActorsList:actors]

        return result
    }

    private func loadEpisodes(info: SeriesInfo, actors: [Actor], season: String, episode: String, language: String) -> [SBMetadataResult] {
        let episodes = session.fetch(episodeForSeriesID: info.id, season: season, episode: episode, language: language)
        let filteredEpisodes = episodes.filter {
            (season.count > 0 ? String($0.airedSeason) == season : true) &&
            (episode.count > 0 ? String($0.airedEpisodeNumber) == episode : true)
        }

        return filteredEpisodes.map { merge(episode: $0, info: info, actors: actors) }
    }

    override public func searchTVSeries(_ seriesName: String, language: String, seasonNum: String, episodeNum: String) -> [SBMetadataResult] {

        let seriesIDs: [Int] =  {
            let result = self.searchIDs(seriesName: seriesName, language: language)
            return result.count > 0 ? result : self.searchIDs(seriesName: seriesName, language: en)
        }()

        var results: [SBMetadataResult] = Array()

        for id in seriesIDs {
            guard let info = session.fetch(seriesInfo: id, language: language) else { continue }
            let actors = session.fetch(actors: id, language: language)
            let episodes = loadEpisodes(info: info, actors: actors, season: seasonNum, episode: episodeNum, language: language)

            results.append(contentsOf: episodes)
        }

        return results
    }

    override public func loadTVMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult? {
        guard let id = metadata["TheTVDB Episodes ID"] else { return metadata }

        if let info = session.fetch(episodeInfo: id as! Int, language: language) {
            metadata[SBMetadataResultDirector] = info.director;
            metadata[SBMetadataResultScreenwriters] = info.writers.first;
        }

        return metadata
    }
}
