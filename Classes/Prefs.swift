//
//  Prefs.swift
//  Subler
//
//  Created by Damiano Galassi on 07/02/2020.
//

import Foundation

private let ud = UserDefaults.standard

private protocol Registable {
    func register(in dictionary: inout [String :Any])
}

private extension UserDefaults {
    func register(defaults values: [Registable]) {
        var defaults = [String : Any]()
        values.forEach { $0.register(in: &defaults) }
        self.register(defaults: defaults)
    }
}

@propertyWrapper
struct Stored<T> : Registable {
    let key: String
    let defaultValue: T

    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get { ud.object(forKey: key) as? T ?? defaultValue }
        set { ud.set(newValue, forKey: key) }
    }

    func register(in dictionary: inout [String :Any]) {
        dictionary[key] = defaultValue
    }
}

@propertyWrapper
struct StoredCodable<T: Codable> : Registable {
    let key: String
    let defaultValue: T

    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            guard let data = ud.data(forKey: key) else { return defaultValue }
            let value = try? JSONDecoder().decode(T.self, from: data)
            return value ?? defaultValue
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            ud.set(data, forKey: key)
        }
    }

    func register(in dictionary: inout [String :Any]) {
        if let data = try? JSONEncoder().encode(defaultValue) {
            dictionary[key] = data
        }
    }
}

enum Prefs {

    static func register() {
        ud.register(defaults: [_crashOnException, _showOpenPanelAtLaunch, _suppressDonationAlert, _fileType, _organizeAlternateGroups,
                               _organizeAlternateGroups, _inferMediaCharacteristics, _audioMixdown,
                               _audioBitrate, _audioDRC, _audioConvertAC3, _audioKeepAC3, _audioConvertDts,
                               _audioDtsOptions, _subtitleConvertBitmap, _ratingsCountry, _chaptersPreviewPosition,
                               _chaptersPreviewTrack, _mp464bitOffset, _mp464bitTimes, _mp4SaveAsOptimize, _forceHvc1,
                               _logFormat])
    }

    @Stored(key: "NSApplicationCrashOnException", defaultValue: true)
    private static var crashOnException: Bool

    @Stored(key: "SBShowOpenPanelAtLaunch", defaultValue: true)
    static var showOpenPanelAtLaunch: Bool

    @Stored(key: "SBIgnoreDonationAlert", defaultValue: false)
    static var suppressDonationAlert: Bool

    @Stored(key: "SBShowQueueWindow", defaultValue: false)
    static var showQueueWindow: Bool

    @Stored(key: "rememberWindowSize", defaultValue: false)
    static var rememberDocumentWindowSize: Bool

    @Stored(key: "SBSaveFormat", defaultValue: "mp4")
    static var fileType: String

    @Stored(key: "SBOrganizeAlternateGroups", defaultValue: true)
    static var organizeAlternateGroups: Bool

    @Stored(key: "SBInferMediaCharacteristics", defaultValue: true)
    static var inferMediaCharacteristics: Bool

    @Stored(key: "SBAudioMixdown", defaultValue: 3)
    static var audioMixdown: UInt

    @Stored(key: "SBAudioBitrate", defaultValue: 96)
    static var audioBitrate: UInt32

    @Stored(key: "SBAudioDRC", defaultValue: 0)
    static var audioDRC: Float

    @Stored(key: "SBAudioConvertAC3", defaultValue: true)
    static var audioConvertAC3: Bool

    @Stored(key: "SBAudioKeepAC3", defaultValue: true)
    static var audioKeepAC3: Bool

    @Stored(key: "SBAudioConvertDts", defaultValue: true)
    static var audioConvertDts: Bool

    @Stored(key: "SBAudioDtsOptions", defaultValue: 0)
    static var audioDtsOptions: UInt

    @Stored(key: "SBSubtitleConvertBitmap", defaultValue: true)
    static var subtitleConvertBitmap: Bool

    @Stored(key: "SBRatingsCountry", defaultValue: "All countries")
    static var ratingsCountry: String

    @Stored(key: "SBChaptersPreviewPosition", defaultValue: 0.5)
    static var chaptersPreviewPosition: Float

    @Stored(key: "chaptersPreviewTrack", defaultValue: true)
    static var chaptersPreviewTrack: Bool

    @Stored(key: "mp464bitOffset", defaultValue: true)
    static var mp464bitOffset: Bool

    @Stored(key: "mp464bitTimes", defaultValue: false)
    static var mp464bitTimes: Bool

    @Stored(key: "mp4SaveAsOptimize", defaultValue: false)
    static var mp4SaveAsOptimize: Bool

    @Stored(key: "SBForceHvc1", defaultValue: true)
    static var forceHvc1: Bool

    @Stored(key: "SBArtworkSelectorZoomLevel", defaultValue: 50)
    static var artworkSelectorZoomLevel: Float

    @Stored(key: "SBMovieArtworkSelectorZoomLevel", defaultValue: 50)
    static var movieArtworkSelectorZoomLevel: Float

    @Stored(key: "SBPresetArtworkSelectorZoomLevel", defaultValue: 0)
    static var presetArtworkSelectorZoomLevel: Float

    @Stored(key: "SBLogFormat", defaultValue: 0)
    static var logFormat: Int  // 0 = Time Only, 1 = Date and Time
}

enum MetadataPrefs {

    static func register() {
        ud.register(defaults: [_setMovieFormat, _setTVShowFormat,
                               _movieImporter, _movieiTunesStoreLanguage,
                               _tvShowImporter, _tvShowiTunesStoreLanguage,
                               _tvShowTheTVDBLanguage, _tvShowTheMovieDBLanguage,
                               _keepEmptyAnnotations, _keepImportedFilesMetadata])
    }

    @StoredCodable(key: "SBMovieFormatTokens", defaultValue: [Token(text: "{Name}")])
    static var movieFormatTokens: [Token]

    @StoredCodable(key: "SBTVShowFormatTokens", defaultValue: [Token(text: "{TV Show}"), Token(text: " s", isPlaceholder: false), Token(text: "{TV Season}"), Token(text: "e", isPlaceholder: false), Token(text: "{TV Episode #}")])
    static var tvShowFormatTokens: [Token]


    @Stored(key: "SBSetMovieFormat", defaultValue: false)
    static var setMovieFormat: Bool

    @Stored(key: "SBSetTVShowFormat", defaultValue: false)
    static var setTVShowFormat: Bool


    @Stored(key: "SBMetadataPreference|Movie", defaultValue: "TheMovieDB")
    static var movieImporter: String

    @Stored(key: "SBMetadataPreference|Movie|iTunes Store|Language", defaultValue: "USA (English)")
    static var movieiTunesStoreLanguage: String

    @Stored(key: "SBMetadataPreference|Movie|TheMovieDB|Language", defaultValue: "en")
    static var movieLanguage: String


    @Stored(key: "SBMetadataPreference|TV", defaultValue: "TheTVDB")
    static var tvShowImporter: String

    @Stored(key: "SBMetadataPreference|TV|iTunes Store|Language", defaultValue: "USA (English)")
    static var tvShowiTunesStoreLanguage: String

    @Stored(key: "SBMetadataPreference|TV|TheTVDB|Language", defaultValue: "en")
    static var tvShowTheTVDBLanguage: String

    @Stored(key: "SBMetadataPreference|TV|TheMovieDB|Language", defaultValue: "en")
    static var tvShowTheMovieDBLanguage: String


    @StoredCodable(key: "SBMetadataMovieResultMap2", defaultValue: MetadataResultMap.movieDefaultMap)
    static var movieResultMap: MetadataResultMap

    @StoredCodable(key: "SBMetadataTvShowResultMap2", defaultValue: MetadataResultMap.tvShowDefaultMap)
    static var tvShowResultMap: MetadataResultMap

    @Stored(key: "SBMetadataKeepEmptyAnnotations", defaultValue: false)
    static var keepEmptyAnnotations: Bool

    @Stored(key: "SBFileImporterImportMetadata", defaultValue: false)
    static var keepImportedFilesMetadata: Bool
}
