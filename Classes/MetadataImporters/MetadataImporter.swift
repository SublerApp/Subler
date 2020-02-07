//
//  MetadataImporter.swift
//  Subler
//
//  Created by Damiano Galassi on 27/07/2017.
//

import Foundation
import MP42Foundation

public enum LanguageType {
    case ISO
    case custom

    public func displayName(language: String) -> String {
        switch self {
        case .ISO:
            return MP42Languages.defaultManager .localizedLang(forExtendedTag: language)
        case .custom:
            return language
        }
    }

    public func extendedTag(displayName: String) -> String {
        switch self {
        case .ISO:
            return MP42Languages.defaultManager.extendedTag(forLocalizedLang: displayName)
        case .custom:
            return displayName
        }
    }
}

public protocol MetadataService {

    var languageType: LanguageType { get }
    var languages: [String] { get }
    var defaultLanguage: String { get }

    var name: String { get }

    func search(tvShow: String, language: String) -> [String]
    func search(tvShow: String, language: String, season: Int?, episode: Int?) -> [MetadataResult]
    func loadTVMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult

    func search(movie: String, language: String) -> [MetadataResult]
    func loadMovieMetadata(_ metadata: MetadataResult, language: String) -> MetadataResult

}

public enum MetadataNameSearch {
    case tvNameSearch(service: MetadataService, tvShow: String, language: String)

    public func search(completionHandler: @escaping ([String]) -> Void) -> Runnable {
        switch self {
        case let .tvNameSearch(service, tvShow, language):
            return RunnableTask(search: service.search(tvShow: tvShow, language: language),
                                              completionHandler: completionHandler)
        }
    }

}

public enum MetadataType : Int, CustomStringConvertible, Codable {
    public var description: String {
        switch self {
        case .movie:
            return "Movie"
        case .tvShow:
            return "TV"
        }
    }

    case movie
    case tvShow
}

public enum MetadataSearch {
    case movieSeach(service: MetadataService, movie: String, language: String)
    case tvSearch(service: MetadataService, tvShow: String, season: Int?, episode: Int?, language: String)

    public func search(completionHandler: @escaping ([MetadataResult]) -> Void) -> Runnable {
        switch self {
        case let .movieSeach(service, movie, language):
            return RunnableTask(search: service.search(movie: movie, language: language),
                                              completionHandler: completionHandler)
        case let .tvSearch(service, tvShow, season, episode, language):
            return RunnableTask(search: service.search(tvShow: tvShow, language: language, season: season, episode: episode),
                                              completionHandler: completionHandler)
        }
    }

    public func loadAdditionalMetadata(_ metadata: MetadataResult, completionHandler: @escaping (MetadataResult) -> Void) -> Runnable {
        switch self {
        case let .movieSeach(service, _, language):
            return RunnableTask(search: service.loadMovieMetadata(metadata, language: language),
                                              completionHandler: completionHandler)
        case let .tvSearch(service, _, _, _, language):
            return RunnableTask(search: service.loadTVMetadata(metadata, language: language),
                                              completionHandler: completionHandler)
        }
    }

    public var type: MetadataType {
        switch self {
        case .movieSeach:
            return .movie
        case .tvSearch:
            return .tvShow
        }
    }
}

extension MetadataSearch {

    public static var movieProviders: [String] { get { return [AppleTV().name, TheMovieDB().name, iTunesStore().name] } }
    public static var tvProviders: [String] { get { return [AppleTV().name, TheMovieDB().name, TheTVDB().name,  iTunesStore().name] } }

    public static func service(name: String?) -> MetadataService {
        switch name {
        case AppleTV().name?:
            return AppleTV()
        case iTunesStore().name?:
            return iTunesStore()
        case TheMovieDB().name?:
            return TheMovieDB()
        case TheTVDB().name?:
            return TheTVDB()
        default:
            return TheMovieDB()
        }
    }

    public static var defaultMovieService: MetadataService {
        get { MetadataSearch.service(name: MetadataPrefs.movieImporter) }
        set { MetadataPrefs.movieImporter = newValue.name }
    }

    public static var defaultTVService: MetadataService {
        get { MetadataSearch.service(name: MetadataPrefs.tvShowImporter) }
        set { MetadataPrefs.tvShowImporter = newValue.name }
    }

    public static func defaultLanguage(service: MetadataService, type: MetadataType) -> String {
        let language = UserDefaults.standard.string(forKey: "SBMetadataPreference|\(type.description)|\(service.name)|Language") ?? service.defaultLanguage
        return service.languageType.displayName(language: language)
    }

    public static func setDefaultLanguage(_ language: String, service: MetadataService, type: MetadataType) {
        let extendedLanguage = service.languageType.extendedTag(displayName: language)
        UserDefaults.standard.set(extendedLanguage, forKey: "SBMetadataPreference|\(type.description)|\(service.name)|Language")
    }

}
