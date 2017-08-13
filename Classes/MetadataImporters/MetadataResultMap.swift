//
//  MetadataResultMap.swift
//  Subler
//
//  Created by Damiano Galassi on 09/08/2017.
//

import Foundation

@objc(SBMetadataResultMapItem) public class MetadataResultMapItem : NSObject, NSSecureCoding {

    @objc public let key: String
    @objc public var value: [String]
    @objc public var localizedKeyDisplayName: String { return localizedMetadataKeyName(key) }

    public init(key: String, value: [String]) {
        self.key = key
        self.value = value
    }

    // MARK: NSSecureCoding

    public static var supportsSecureCoding: Bool { return true }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(key, forKey: "key")
        aCoder.encode(value, forKey: "value")
    }

    required public init?(coder aDecoder: NSCoder) {
        guard let key = aDecoder.decodeObject(of: NSString.self, forKey: "key") as String?,
              let value = aDecoder.decodeObject(of: [NSArray.self, NSString.self], forKey: "value") as? [String]
            else { return nil }
        self.key = key
        self.value = value
    }

}

@objc(SBMetadataResultMap) public class MetadataResultMap : NSObject, NSSecureCoding {

    @objc public static var movieDefaultMap: MetadataResultMap {
        let items = [ MetadataResultMapItem(key: MP42MetadataKeyName,               value:[MetadataResult.Key.name.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyArtist,             value:[MetadataResult.Key.director.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyComposer,           value:[MetadataResult.Key.composer.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyUserGenre,          value:[MetadataResult.Key.genre.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyReleaseDate,        value:[MetadataResult.Key.releaseDate.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyDescription,        value:[MetadataResult.Key.description.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyLongDescription,    value:[MetadataResult.Key.longDescription.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyRating,             value:[MetadataResult.Key.rating.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyStudio,             value:[MetadataResult.Key.studio.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyCast,               value:[MetadataResult.Key.cast.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyDirector,           value:[MetadataResult.Key.director.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyProducer,           value:[MetadataResult.Key.producers.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyScreenwriters,      value:[MetadataResult.Key.screenwriters.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyCopyright,          value:[MetadataResult.Key.copyright.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyContentID,          value:[MetadataResult.Key.contentID.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyAccountCountry,     value:[MetadataResult.Key.iTunesCountry.rawValue]),
                      MetadataResultMapItem(key: MP42MetadataKeyExecProducer,       value:[MetadataResult.Key.executiveProducer.rawValue])]

        return MetadataResultMap(items: items, type: .movie)
    }

    @objc public static var tvShowDefaultMap: MetadataResultMap {
        let items = [MetadataResultMapItem(key: MP42MetadataKeyName,           value:[MetadataResult.Key.name.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyArtist,         value:[MetadataResult.Key.seriesName.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyAlbumArtist,    value:[MetadataResult.Key.seriesName.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyAlbum,          value:[MetadataResult.Key.seriesName.rawValue, ", Season ", MetadataResult.Key.season.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyComposer,       value:[MetadataResult.Key.composer.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyUserGenre,      value:[MetadataResult.Key.genre.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyReleaseDate,    value:[MetadataResult.Key.releaseDate.rawValue]),

                     MetadataResultMapItem(key: MP42MetadataKeyTrackNumber,        value:[MetadataResult.Key.trackNumber.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyDiscNumber,         value:[MetadataResult.Key.diskNumber.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVShow,             value:[MetadataResult.Key.seriesName.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVEpisodeNumber,    value:[MetadataResult.Key.episodeNumber.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVNetwork,          value:[MetadataResult.Key.network.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVEpisodeID,        value:[MetadataResult.Key.episodeID.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVSeason,           value:[MetadataResult.Key.season.rawValue]),

                     MetadataResultMapItem(key: MP42MetadataKeyDescription,        value:[MetadataResult.Key.description.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyLongDescription,    value:[MetadataResult.Key.longDescription.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeySeriesDescription,  value:[MetadataResult.Key.seriesDescription.rawValue]),

                     MetadataResultMapItem(key: MP42MetadataKeyRating,             value:[MetadataResult.Key.rating.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyStudio,             value:[MetadataResult.Key.studio.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyCast,               value:[MetadataResult.Key.cast.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyDirector,           value:[MetadataResult.Key.director.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyProducer,           value:[MetadataResult.Key.producers.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyScreenwriters,      value:[MetadataResult.Key.screenwriters.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyExecProducer,       value:[MetadataResult.Key.executiveProducer.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyCopyright,          value:[MetadataResult.Key.copyright.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyContentID,          value:[MetadataResult.Key.contentID.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyArtistID,           value:[MetadataResult.Key.artistID.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyPlaylistID,         value:[MetadataResult.Key.playlistID.rawValue]),
                     MetadataResultMapItem(key: MP42MetadataKeyAccountCountry,     value:[MetadataResult.Key.iTunesCountry.rawValue])]

        return MetadataResultMap(items: items, type: .tvShow)
    }

    @objc public var items: [MetadataResultMapItem]
    public let type: MetadataType

    init(items: [MetadataResultMapItem], type: MetadataType) {
        self.items = items
        self.type = type
    }

    // MARK: NSSecureCoding

    public static var supportsSecureCoding: Bool { return true }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(items, forKey: "items")
        aCoder.encode(Int32(type.rawValue), forKey: "type")
    }

    required public init?(coder aDecoder: NSCoder) {
        guard let items = aDecoder.decodeObject(of: [NSArray.self, MetadataResultMapItem.self], forKey: "items") as? [MetadataResultMapItem],
            let type = MetadataType(rawValue: Int(aDecoder.decodeInt32(forKey: "type")))
            else { return nil }
        self.items = items
        self.type = type
    }

}

extension UserDefaults {

    @objc func map(forKey defaultName: String) -> MetadataResultMap? {
        guard let data = self.data(forKey: defaultName) else { return nil }

        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        unarchiver.requiresSecureCoding = true

        return unarchiver.decodeObject(of: MetadataResultMap.self, forKey: NSKeyedArchiveRootObjectKey)
    }

    func set(_ map: MetadataResultMap, forKey defaultName: String) {
        let data = NSKeyedArchiver.archivedData(withRootObject: map)
        self.set(data, forKey: defaultName)
    }

}
