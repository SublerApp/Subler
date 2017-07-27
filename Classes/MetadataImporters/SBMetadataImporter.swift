//
//  SBMetadataImporter.swift
//  Subler
//
//  Created by Damiano Galassi on 27/07/2017.
//

import Foundation

@objc public class SBMetadataImporter : NSObject {

    @objc public static var movieProviders: [String] {
        get {
            return MetadataServiceType.movieProviders
        }
    }

    @objc public static var tvProviders: [String] {
        get {
            return MetadataServiceType.tvProviders
        }
    }

    @objc public static func languages(provider: String) -> [String] {
        return MetadataServiceType.service(name: provider).languages
    }

    @objc public static func languageType(provider: String) -> SBMetadataImporterLanguageType {
        return MetadataServiceType.service(name: provider).languageType
    }

    @objc public static func defaultLanguage(provider: String) -> String {
        return MetadataServiceType.service(name: provider).defaultLanguage
    }

    @objc public static func importer(provider: String) -> SBMetadataImporter {
        return SBMetadataImporter(provider: provider)
    }

    @objc public static var defaultMovieProvider: SBMetadataImporter {
        get {
            return SBMetadataImporter(service: MetadataServiceType.defaultMovieProvider)
        }
    }

    @objc public static var defaultTVProvider: SBMetadataImporter {
        get {
            return SBMetadataImporter(service: MetadataServiceType.defaultTVProvider)
        }
    }

    @objc public static var defaultMovieLanguage: String {
        get {
            let defaults = UserDefaults.standard
            return defaults.string(forKey: "SBMetadataPreference|Movie|\(defaults.value(forKey: "SBMetadataPreference|Movie")!)|Language")!
        }
    }

    @objc public static var defaultTVLanguage: String {
        get {
            let defaults = UserDefaults.standard
            return defaults.string(forKey: "SBMetadataPreference|TV|\(defaults.value(forKey: "SBMetadataPreference|TV")!)|Language")!
        }
    }

    private let service: MetadataService
    private var currentSearch: MetadataSearch?
    private var currentSearchTask: MetadataSearchTask?

    @objc init(provider: String) {
        service = MetadataServiceType.service(name: provider)
    }

    init(service: MetadataService) {
        self.service = service
    }

    @objc public var languageType: SBMetadataImporterLanguageType {
        get {
            return service.languageType
        }
    }

    @objc public var languages: [String] {
        get {
            return service.languages
        }
    }

    @objc public func search(movie: String, language: String, completionHandler: @escaping ([SBMetadataResult]) -> Void) {
        currentSearch = MetadataSearch.movieSeach(service: service, movie: movie, language: language)
        currentSearchTask = currentSearch?.search(completionHandler: completionHandler).runAsync()
    }

    @objc public func loadFullMetadata(_ metadata: SBMetadataResult, language: String, completionHandler: @escaping (SBMetadataResult) -> Void) {
        if metadata.mediaKind == 9 {
            currentSearch = MetadataSearch.movieSeach(service: service, movie: "", language: language)
            currentSearchTask = currentSearch?.loadAdditionalMetadata(metadata, completionHandler: completionHandler).runAsync()
        }
        else if metadata.mediaKind == 10 {
            currentSearch = MetadataSearch.tvSearch(service: service, tvSeries: "", season: nil, episode: nil, language: language)
            currentSearchTask = currentSearch?.loadAdditionalMetadata(metadata, completionHandler: completionHandler).runAsync()
        }
    }

    @objc public func search(tvSeries: String, language: String, completionHandler: @escaping ([String]) -> Void) {
        //importer.search(tvSeries: tvSeries, language: language, completionHandler: completionHandler);
    }

    @objc public func search(tvSeries: String, language: String, seasonNum: String, episodeNum: String, completionHandler: @escaping ([SBMetadataResult]) -> Void) {
        currentSearch = MetadataSearch.tvSearch(service: service, tvSeries: tvSeries, season: Int(seasonNum), episode: Int(episodeNum), language: language)
        currentSearchTask = currentSearch?.search(completionHandler: completionHandler).runAsync()
    }

    @objc public func cancel() {
        currentSearchTask?.cancel()
    }
}
