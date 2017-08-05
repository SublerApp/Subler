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
            return MetadataSearch.movieProviders
        }
    }

    @objc public static var tvProviders: [String] {
        get {
            return MetadataSearch.tvProviders
        }
    }

    @objc public static func languages(provider: String) -> [String] {
        return MetadataSearch.service(name: provider).languages
    }

    @objc public static func languageType(provider: String) -> LanguageType {
        return MetadataSearch.service(name: provider).languageType
    }

    @objc public static func defaultLanguage(provider: String) -> String {
        return MetadataSearch.service(name: provider).defaultLanguage
    }

    @objc public static func importer(provider: String) -> SBMetadataImporter {
        return SBMetadataImporter(provider: provider)
    }

    private let service: MetadataService

    @objc init(provider: String) {
        service = MetadataSearch.service(name: provider)
    }

    init(service: MetadataService) {
        self.service = service
    }

    @objc public var languageType: LanguageType {
        get {
            return service.languageType
        }
    }

    @objc public var languages: [String] {
        get {
            return service.languages
        }
    }
}