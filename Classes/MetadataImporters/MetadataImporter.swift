//
//  MetadataImporter.swift
//  Subler
//
//  Created by Damiano Galassi on 27/07/2017.
//

import Foundation

public protocol MetadataService {

    var languageType: SBMetadataImporterLanguageType { get }
    var languages: [String] { get }
    var defaultLanguage: String { get }

    func search(TVSeries: String, language: String, season: Int?, episode: Int?) -> [SBMetadataResult]
    func loadTVMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult

    func search(movie: String, language: String) -> [SBMetadataResult]
    func loadMovieMetadata(_ metadata: SBMetadataResult, language: String) -> SBMetadataResult

}

public protocol MetadataNameService {

    func search(TVSeries: String, language: String) -> [String]

}

public enum MetadataServiceType : String {
    case iTunesStoreService = "iTunes Store"
    case TheMovieDBService = "TheMovieDB"
    case TheTVDBService = "TheTVDB"

    public static var movieProviders: [String] { get { return ["TheMovieDB", "iTunes Store"] } }
    public static var tvProviders: [String] { get { return ["TheMovieDB", "TheTVDB", "iTunes Store"] } }

    public static func service(type: MetadataServiceType) -> MetadataService {
        switch type {
        case .iTunesStoreService:
            return iTunesStore()
        case .TheMovieDBService:
            return TheMovieDB()
        case .TheTVDBService:
            return TheTVDB()
        }
    }

    public static func service(name: String?) -> MetadataService {
        if let name = name, let type = MetadataServiceType(rawValue: name) {
            return MetadataServiceType.service(type: type)
        }
        else {
            return MetadataServiceType.service(type: .TheMovieDBService)
        }
    }

    public static var defaultMovieProvider: MetadataService {
        get {
            return  MetadataServiceType.service(name: UserDefaults.standard.string(forKey: "SBMetadataPreference|Movie"))
        }
    }

    public static var defaultTVProvider: MetadataService {
        get {
            return  MetadataServiceType.service(name: UserDefaults.standard.string(forKey: "SBMetadataPreference|TV"))
        }
    }

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
}

public protocol MetadataSearchTask {
    func runAsync() -> MetadataSearchTask
    func run() -> MetadataSearchTask
    func cancel()
}

private class MetadataSearchInternalTask<T> : MetadataSearchTask {

    private var cancelled: Bool = false
    private let search: () -> T
    private let completionHandler: (T) -> Void

    fileprivate init(search: @escaping @autoclosure () -> T, completionHandler: @escaping (T) -> Void) {
        self.search = search
        self.completionHandler = completionHandler
    }

    public func runAsync() -> MetadataSearchTask {
        DispatchQueue.global(priority: .background).async {
            _ = self.run()
        }
        return self
    }

    public func run() -> MetadataSearchTask {
        let results = self.search()
        if self.cancelled == false {
            self.completionHandler(results)
        }
        return self
    }

    public func cancel() {
        self.cancelled = true
    }
}
