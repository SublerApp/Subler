//
//  Document+Swift.swift
//  Subler
//
//  Created by Damiano Galassi on 11/08/2017.
//

import Foundation

extension SBDocument: ChapterSearchControllerDelegate, MetadataSearchControllerDelegate, FileImportControllerDelegate {

    // MARK: File name

    @objc func preferredFileName() -> String? {
        if let mediaKind = mp4.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyMediaKind).first?.numberValue?.intValue,
            (mediaKind == 10 && UserDefaults.standard.bool(forKey: "SBSetTVShowFormat")) ||
            (mediaKind == 9 && UserDefaults.standard.bool(forKey: "SBSetMovieFormat")),
            let name = mp4.formattedFileName() {
            return name
        } else {
            return mp4.tracks.flatMap { $0.url }.first?.deletingPathExtension().lastPathComponent
        }
    }

    // MARK: Metadata

    @IBAction func searchMetadata(_ sender: Any?) {
        let terms = mp4.extractSearchTerms(fallbackURL : fileURL)
        let controller = MetadataSearchController(delegate: self, searchTerms: terms)

        guard let windowForSheet = windowForSheet, let window = controller.window
            else { return }

        sheetController = controller;
        windowForSheet.beginSheet(window, completionHandler: { response in
            self.sheetController = nil
        })
    }

    @IBAction func searchChapters(_ sender: Any?) {
        let name = mp4.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyName).first?.stringValue
        let url = mp4.firstSourceURL() ?? self.fileURL
        let title = (name?.isEmpty == false ? name : url?.lastPathComponent) ?? ""
        let duration = UInt64(mp4.duration)

        let controller = ChapterSearchController(delegate: self, title: title, duration: duration)

        guard let windowForSheet = windowForSheet, let window = controller.window
            else { return }

        sheetController = controller;
        windowForSheet.beginSheet(window, completionHandler: { response in
            self.sheetController = nil
        })
    }

    func didSelect(metadata: MetadataResult) {
        let defaults = UserDefaults.standard
        let map = metadata.mediaKind == 9 ? defaults.map(forKey: "SBMetadataMovieResultMap") : defaults.map(forKey: "SBMetadataTvShowResultMap")
        let keepEmptyKeys = defaults.bool(forKey: "SBMetadataKeepEmptyAnnotations")

        if let map = map {
            let result = metadata.mappedMetadata(to: map, keepEmptyKeys: keepEmptyKeys)
            mp4.metadata.merge(result)
        }

        if let hdType = mp4.hdType {
            for item in mp4.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyHDVideo) {
                mp4.metadata.removeItem(item)
            }
            mp4.metadata.addItem(MP42MetadataItem(identifier: MP42MetadataKeyHDVideo, value: NSNumber(value: hdType.rawValue),
                                                  dataType: .integer, extendedLanguageTag: nil))
        }
        updateChangeCount(.changeDone)
        reload()
    }

    func didSelect(chapters: [MP42TextSample]) {
        let chapterTrack = MP42ChapterTrack()
        for chapter in chapters {
            chapterTrack.addChapter(chapter)
        }

        mp4.addTrack(chapterTrack)
        updateChangeCount(.changeDone)
        reload()
    }

    // MARK: File import

    @objc func showImportSheet(fileURLs: [URL]) {
        do {
            let controller = try FileImportController(fileURLs: fileURLs, delegate: self)

            if controller.onlyContainsSubtitles {
                controller.addTracks(self)
                tracksTable?.reloadData()
                reloadPropertyView()
                self.sheetController = nil;
            }
            else {
                guard let windowForSheet = windowForSheet, let window = controller.window
                    else { return }

                sheetController = controller;
                windowForSheet.beginSheet(window, completionHandler: { response in
                    self.sheetController = nil
                })
            }
        }
        catch {
            if let windowForSheet = windowForSheet {
                presentError(error, modalFor: windowForSheet, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                presentError(error)
            }
        }
    }

    func didSelect(tracks: [MP42Track], metadata: MP42Metadata?) {
        for track in tracks {
            mp4.addTrack(track)
        }

        if tracks.isEmpty == false {
            updateChangeCount(.changeDone)

            if UserDefaults.standard.bool(forKey: "SBOrganizeAlternateGroups") {
                mp4.organizeAlternateGroups()
                if UserDefaults.standard.bool(forKey: "SBInferMediaCharacteristics") {
                    mp4.inferMediaCharacteristics()
                }
            }
        }

        if let metadata = metadata {
            mp4.metadata.merge(metadata)
            updateChangeCount(.changeDone)
        }

        tracksTable?.reloadData()
        reloadPropertyView()
    }

}
