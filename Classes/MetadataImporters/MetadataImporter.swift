//
//  MetadataImporter.swift
//  Subler
//
//  Created by Damiano Galassi on 27/07/2017.
//

import Foundation

@objc(SBMetadataImporterLanguageType) public enum LanguageType: Int {
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

    func search(TVSeries: String, language: String, season: Int?, episode: Int?) -> [SBMetadataResult]
    func loadTVMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult

    func search(movie: String, language: String) -> [SBMetadataResult]
    func loadMovieMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult

}

public protocol MetadataNameService {

    func search(TVSeries: String, language: String) -> [String]

}

public enum MetadataNameSearch {
    case tvNameSearch(service: MetadataNameService, tvSeries: String, language: String)

    public func search(completionHandler: @escaping ([String]) -> Void) -> MetadataSearchTask {
        switch self {
        case let .tvNameSearch(service, tvSeries, language):
            return MetadataSearchInternalTask(search: service.search(TVSeries: tvSeries, language: language),
                                              completionHandler: completionHandler)
        }
    }

}

public enum MetadataSearch {
    case movieSeach(service: MetadataService, movie: String, language: String)
    case tvSearch(service: MetadataService, tvSeries: String, season: Int?, episode: Int?, language: String)

    public func search(completionHandler: @escaping ([SBMetadataResult]) -> Void) -> MetadataSearchTask {
        switch self {
        case let .movieSeach(service, movie, language):
            return MetadataSearchInternalTask(search: service.search(movie: movie, language: language),
                                              completionHandler: completionHandler)
        case let .tvSearch(service, tvSeries, season, episode, language):
            return MetadataSearchInternalTask(search: service.search(TVSeries: tvSeries, language: language, season: season, episode: episode),
                                              completionHandler: completionHandler)
        }
    }

    public func loadAdditionalMetadata(_ metadata: SBMetadataResult, completionHandler: @escaping (SBMetadataResult) -> Void) -> MetadataSearchTask {
        switch self {
        case let .movieSeach(service, _, language):
            return MetadataSearchInternalTask(search: service.loadMovieMetadata(metadata, language: language),
                                              completionHandler: completionHandler)
        case let .tvSearch(service, _, _, _, language):
            return MetadataSearchInternalTask(search: service.loadTVMetadata(metadata, language: language),
                                              completionHandler: completionHandler)
        }
    }

    public enum MetadataSearchType: String {
        case movie = "Movie"
        case tvShow = "TV"
    }

    public var type: MetadataSearchType {
        get {
            switch self {
            case .movieSeach:
                return .movie
            case .tvSearch:
                return .tvShow
            }
        }
    }
}

extension MetadataSearch {

    public static var movieProviders: [String] { get { return [TheMovieDB().name, iTunesStore().name] } }
    public static var tvProviders: [String] { get { return [TheMovieDB().name, TheTVDB().name,  iTunesStore().name] } }

    public static func service(name: String?) -> MetadataService {
        switch name {
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
        get {
            return  MetadataSearch.service(name: UserDefaults.standard.string(forKey: "SBMetadataPreference|Movie"))
        }
        set {
            UserDefaults.standard.set(defaultMovieService.name, forKey: "SBMetadataPreference|Movie")
        }
    }

    public static var defaultTVService: MetadataService {
        get {
            return  MetadataSearch.service(name: UserDefaults.standard.string(forKey: "SBMetadataPreference|TV"))
        }
        set {
            UserDefaults.standard.set(defaultMovieService.name, forKey: "SBMetadataPreference|TV")
        }
    }

    public static func defaultLanguage(service: MetadataService, type: MetadataSearchType) -> String {
        let language = UserDefaults.standard.string(forKey: "SBMetadataPreference|\(type.rawValue)|\(service.name)|Language") ?? service.defaultLanguage
        return service.languageType.displayName(language: language)
    }

    public static func setDefaultLanguage(_ language: String, service: MetadataService, type: MetadataSearchType) {
        let extendedLanguage = service.languageType.extendedTag(displayName: language)
        UserDefaults.standard.set(extendedLanguage, forKey: "SBMetadataPreference|\(type.rawValue)|\(service.name)|Language")
    }

}
