//
//  Document+Swift.swift
//  Subler
//
//  Created by Damiano Galassi on 11/08/2017.
//

import Foundation

extension MP42File {
    fileprivate func hdType() -> Int32? {
        for track in self.tracks(withMediaType: kMP42MediaType_Video) as! [MP42VideoTrack] {
            return isHdVideo(UInt64(track.trackWidth), UInt64(track.trackHeight))
        }
        return nil
    }
}

extension SBDocument: ChapterSearchControllerDelegate, MetadataSearchControllerDelegate {
    
    func didSelect(metadata: MetadataResult) {
        let defaults = UserDefaults.standard
        let map = metadata.mediaKind == 9 ? defaults.map(forKey: "SBMetadataMovieResultMap") : defaults.map(forKey: "SBMetadataTvShowResultMap")
        let keepEmptyKeys = defaults.bool(forKey: "SBMetadataKeepEmptyAnnotations")
        
        let result = metadata.mappedMetadata(to: map!, keepEmptyKeys: keepEmptyKeys)
        mp4.metadata.merge(result)
        
        if let hdType = mp4.hdType() {
            for item in mp4.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyHDVideo) {
                mp4.metadata.removeItem(item)
            }
            mp4.metadata.addItem(MP42MetadataItem(identifier: MP42MetadataKeyHDVideo, value: NSNumber(value: hdType),
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

}
