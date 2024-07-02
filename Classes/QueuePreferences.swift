//
//  QueuePreferences.swift
//  Subler
//
//  Created by Damiano Galassi on 28/03/2018.
//

import Foundation

final class QueuePreferences: NSObject {

    static private let SBQueueFileType: String = "SBQueueFileType"
    static private let SBQueueOrganize: String = "SBQueueOrganize"
    static private let SBQueueFixFallbacks: String = "SBQueueFixFallbacks"
    static private let SBQueueClearTrackName: String = "SBQueueClearTrackName"
    static private let SBQueuePrettifyAudioTrackName: String = "SBQueuePrettifyAudioTrackName"
    static private let SBQueueRenameChapters: String = "SBQueueRenameChapters"
    static private let SBQueueMetadata: String = "SBQueueMetadata"
    static private let SBQueueSubtitles: String = "SBQueueSubtitles"
    static private let SBQueueSet: String = "SBQueueSet"

    static private let SBQueueAutoStart: String = "SBQueueAutoStart"
    static private let SBQueueOptimize: String = "SBQueueOptimize"
    static private let SBQueueSendToiTunes: String = "SBQueueSendToiTunes"
    static private let SBQueueShowDoneNotification: String = "SBQueueShowDoneNotification"

    static private let SBQueueFixTrackLanguage: String = "SBQueueFixTrackLanguage"
    static private let SBQueueFixTrackLanguageValue: String = "SBQueueFixTrackLanguageValue"

    static private let SBQueueApplyColorSpace: String = "SBQueueApplyColorSpace"
    static private let SBQueueApplyColorSpaceValue: String = "SBQueueApplyColorSpaceValue"

    static private let SBQueueClearExistingMetadata: String = "SBQueueClearExistingMetadata"

    static private let SBQueueMovieProvider: String = "SBQueueMovieProvider"
    static private let SBQueueTVShowProvider: String = "SBQueueTVShowProvider"
    static private let SBQueueMovieProviderLanguage: String = "SBQueueMovieProviderLanguage"
    static private let SBQueueTVShowProviderLanguage: String = "SBQueueTVShowProviderLanguage"
    static private let SBQueueProviderArtwork: String = "SBQueueProviderArtwork2"
    static private let SBQueueProviderArtworkSize: String = "SBQueueProviderArtworkSize"

    static private let SBQueueSetOutputFilename: String = "SBQueueSetOutputFilename"
    static private let SBQueueDestination: String = "SBQueueDestination"

    static private let SBQueueChangeAudioLanguage: String = "SBQueueChangeAudioLanguage"
    static private let SBQueueChangeAudioLanguageValue: String = "SBQueueChangeAudioLanguageValue"
    static private let SBQueueChangeSubtitleLanguage: String = "SBQueueChangeSubtitleLanguage"
    static private let SBQueueChangeSubtitleLanguageValue: String = "SBQueueChangeSubtitleLanguageValue"

    @objc dynamic var clearExistingMetadata: Bool

    @objc dynamic var searchMetadata: Bool
    @objc dynamic var movieProvider: String
    @objc dynamic var movieProviderLanguage: String
    @objc dynamic var tvShowProvider: String
    @objc dynamic var tvShowProviderLanguage: String
    @objc dynamic var providerArtwork: Int
    @objc dynamic var providerArtworkSize: Int

    @objc dynamic var organize: Bool
    @objc dynamic var fixFallbacks: Bool
    @objc dynamic var clearTrackName: Bool
    @objc dynamic var prettifyAudioTrackName: Bool
    @objc dynamic var renameChapters: Bool
    @objc dynamic var subtitles: Bool
    @objc dynamic var metadataSet: MetadataPreset?

    @objc dynamic var fixTrackLanguage: Bool
    @objc dynamic var fixTrackLanguageValue: String

    @objc dynamic var applyColorSpace: Bool
    @objc dynamic var applyColorSpaceValue: Int

    @objc dynamic var setOutputFilename: Bool
    @objc dynamic var fileType: String
    @objc dynamic var destination: URL?

    @objc dynamic var optimize: Bool
    @objc dynamic var sendToiTunes: Bool

    @objc dynamic var autoStart: Bool
    @objc dynamic var showDoneNotification: Bool

    @objc dynamic var changeAudioLanguage: Bool
    @objc dynamic var changeAudioLanguageValue: String
    @objc dynamic var changeSubtitleLanguage: Bool
    @objc dynamic var changeSubtitleLanguageValue: String

    override init() {
        QueuePreferences.registerUserDefaults()

        let ud = UserDefaults.standard

        self.clearExistingMetadata = ud.bool(forKey: QueuePreferences.SBQueueClearExistingMetadata)

        self.searchMetadata = ud.bool(forKey: QueuePreferences.SBQueueMetadata)
        self.movieProvider = ud.string(forKey: QueuePreferences.SBQueueMovieProvider) ?? "TheMovieDB"
        self.movieProviderLanguage = ud.string(forKey: QueuePreferences.SBQueueMovieProviderLanguage) ?? "en"
        self.tvShowProvider = ud.string(forKey: QueuePreferences.SBQueueTVShowProvider) ?? "TheTVDB"
        self.tvShowProviderLanguage = ud.string(forKey: QueuePreferences.SBQueueTVShowProviderLanguage) ?? "en"
        self.providerArtwork = ud.integer(forKey: QueuePreferences.SBQueueProviderArtwork)
        self.providerArtworkSize = ud.integer(forKey: QueuePreferences.SBQueueProviderArtworkSize)

        self.organize = ud.bool(forKey: QueuePreferences.SBQueueOrganize)
        self.fixFallbacks = ud.bool(forKey: QueuePreferences.SBQueueFixFallbacks)
        self.clearTrackName = ud.bool(forKey: QueuePreferences.SBQueueClearTrackName)
        self.prettifyAudioTrackName = ud.bool(forKey: QueuePreferences.SBQueuePrettifyAudioTrackName)
        self.renameChapters = ud.bool(forKey: QueuePreferences.SBQueueRenameChapters)
        self.subtitles = ud.bool(forKey: QueuePreferences.SBQueueSubtitles)
        if let presetName = ud.string(forKey: QueuePreferences.SBQueueSet) {
            self.metadataSet = PresetManager.shared.item(name: presetName) as? MetadataPreset
        }

        self.fixTrackLanguage = ud.bool(forKey: QueuePreferences.SBQueueFixTrackLanguage)
        self.fixTrackLanguageValue = ud.string(forKey: QueuePreferences.SBQueueFixTrackLanguageValue) ?? ""

        self.applyColorSpace = ud.bool(forKey: QueuePreferences.SBQueueApplyColorSpace)
        self.applyColorSpaceValue = ud.integer(forKey: QueuePreferences.SBQueueApplyColorSpaceValue)

        self.setOutputFilename = ud.bool(forKey: QueuePreferences.SBQueueSetOutputFilename)
        self.fileType = ud.string(forKey: QueuePreferences.SBQueueFileType) ?? "mp4"
        if let url = ud.url(forKey: QueuePreferences.SBQueueDestination), FileManager.default.fileExists(atPath: url.path) {
            self.destination = url
        }

        self.optimize = ud.bool(forKey: QueuePreferences.SBQueueOptimize)
        self.sendToiTunes = ud.bool(forKey: QueuePreferences.SBQueueSendToiTunes)

        self.autoStart = ud.bool(forKey: QueuePreferences.SBQueueAutoStart)
        self.showDoneNotification = ud.bool(forKey: QueuePreferences.SBQueueShowDoneNotification)

        self.changeAudioLanguage = ud.bool(forKey: QueuePreferences.SBQueueChangeAudioLanguage)
        self.changeAudioLanguageValue = ud.string(forKey: QueuePreferences.SBQueueChangeAudioLanguageValue) ?? ""
        self.changeSubtitleLanguage = ud.bool(forKey: QueuePreferences.SBQueueChangeSubtitleLanguage)
        self.changeSubtitleLanguageValue = ud.string(forKey: QueuePreferences.SBQueueChangeSubtitleLanguageValue) ?? ""
    }

    convenience init(preset: QueuePreset) {
        self.init()
    }

    static func registerUserDefaults() {
        let prefs = [QueuePreferences.SBQueueFileType: "mp4",
                     QueuePreferences.SBQueueOrganize: true,
                     QueuePreferences.SBQueueFixTrackLanguage: false,
                     QueuePreferences.SBQueueFixTrackLanguageValue: "en",
                     QueuePreferences.SBQueueFixFallbacks: false,
                     QueuePreferences.SBQueueClearTrackName: false,
                     QueuePreferences.SBQueuePrettifyAudioTrackName: false,
                     QueuePreferences.SBQueueRenameChapters: false,
                     QueuePreferences.SBQueueMetadata: false,
                     QueuePreferences.SBQueueSubtitles: true,
                     QueuePreferences.SBQueueApplyColorSpace: false,
                     QueuePreferences.SBQueueApplyColorSpaceValue: 1,
                     QueuePreferences.SBQueueSetOutputFilename: false,
                     QueuePreferences.SBQueueAutoStart: false,
                     QueuePreferences.SBQueueOptimize: false,
                     QueuePreferences.SBQueueShowDoneNotification: true,
                     QueuePreferences.SBQueueClearExistingMetadata: false,
                     QueuePreferences.SBQueueMovieProvider: "TheMovieDB",
                     QueuePreferences.SBQueueTVShowProvider: "TheTVDB",
                     QueuePreferences.SBQueueMovieProviderLanguage: "en",
                     QueuePreferences.SBQueueTVShowProviderLanguage: "en",
                     QueuePreferences.SBQueueProviderArtwork: 0,
                     QueuePreferences.SBQueueProviderArtworkSize: 0,
                     QueuePreferences.SBQueueChangeAudioLanguage: false,
                     QueuePreferences.SBQueueChangeAudioLanguageValue: "en",
                     QueuePreferences.SBQueueChangeSubtitleLanguage: false,
                     QueuePreferences.SBQueueChangeSubtitleLanguageValue: "en"] as [String : Any]
        UserDefaults.standard.register(defaults: prefs)
    }

    func saveUserDefaults() {
        let ud = UserDefaults.standard

        ud.set(clearExistingMetadata, forKey: QueuePreferences.SBQueueClearExistingMetadata)

        ud.set(searchMetadata, forKey: QueuePreferences.SBQueueMetadata)
        ud.set(movieProvider, forKey: QueuePreferences.SBQueueMovieProvider)
        ud.set(movieProviderLanguage, forKey: QueuePreferences.SBQueueMovieProviderLanguage)
        ud.set(tvShowProvider, forKey: QueuePreferences.SBQueueTVShowProvider)
        ud.set(tvShowProviderLanguage, forKey: QueuePreferences.SBQueueTVShowProviderLanguage)
        ud.set(providerArtwork, forKey: QueuePreferences.SBQueueProviderArtwork)
        ud.set(providerArtworkSize, forKey: QueuePreferences.SBQueueProviderArtworkSize)

        ud.set(organize, forKey: QueuePreferences.SBQueueOrganize)
        ud.set(fixFallbacks, forKey: QueuePreferences.SBQueueFixFallbacks)
        ud.set(clearTrackName, forKey: QueuePreferences.SBQueueClearTrackName)
        ud.set(prettifyAudioTrackName, forKey: QueuePreferences.SBQueuePrettifyAudioTrackName)
        ud.set(renameChapters, forKey: QueuePreferences.SBQueueRenameChapters)
        ud.set(subtitles, forKey: QueuePreferences.SBQueueSubtitles)
        ud.set(metadataSet?.title, forKey: QueuePreferences.SBQueueSet)

        ud.set(fixTrackLanguage, forKey: QueuePreferences.SBQueueFixTrackLanguage)
        ud.set(fixTrackLanguageValue, forKey: QueuePreferences.SBQueueFixTrackLanguageValue)

        ud.set(applyColorSpace, forKey: QueuePreferences.SBQueueApplyColorSpace)
        ud.set(applyColorSpaceValue, forKey: QueuePreferences.SBQueueApplyColorSpaceValue)

        ud.set(setOutputFilename, forKey: QueuePreferences.SBQueueSetOutputFilename)
        ud.set(fileType, forKey: QueuePreferences.SBQueueFileType)
        ud.set(destination, forKey: QueuePreferences.SBQueueDestination)

        ud.set(optimize, forKey: QueuePreferences.SBQueueOptimize)
        ud.set(sendToiTunes, forKey: QueuePreferences.SBQueueSendToiTunes)

        ud.set(autoStart, forKey: QueuePreferences.SBQueueAutoStart)
        ud.set(showDoneNotification, forKey: QueuePreferences.SBQueueShowDoneNotification)

        ud.set(changeAudioLanguage, forKey: QueuePreferences.SBQueueChangeAudioLanguage)
        ud.set(changeAudioLanguageValue, forKey: QueuePreferences.SBQueueChangeAudioLanguageValue)
        ud.set(changeSubtitleLanguage, forKey: QueuePreferences.SBQueueChangeSubtitleLanguage)
        ud.set(changeSubtitleLanguageValue, forKey: QueuePreferences.SBQueueChangeSubtitleLanguageValue)
    }

    var queueURL: URL? {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Subler").appendingPathComponent("queue.sbqueue", isDirectory: false)
    }
}
