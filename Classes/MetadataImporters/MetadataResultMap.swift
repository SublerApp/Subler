//
//  MetadataResultMap.swift
//  Subler
//
//  Created by Damiano Galassi on 09/08/2017.
//

import Foundation
import MP42Foundation

public class MetadataResultMapItem: Codable {

    public let key: String
    public var value: [Token]
    public var localizedKeyDisplayName: String { return localizedMetadataKeyName(key) }

    public init(key: String, value: [Token] = []) {
        self.key = key
        self.value = value
    }
}

public class MetadataResultMap: Codable {

    public static var movieDefaultMap: MetadataResultMap {
        let items = [ MetadataResultMapItem(key: MP42MetadataKeyName,               value:[MetadataResult.Key.name.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyArtist,             value:[MetadataResult.Key.director.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyComposer,           value:[MetadataResult.Key.composer.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyUserGenre,          value:[MetadataResult.Key.genre.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyReleaseDate,        value:[MetadataResult.Key.releaseDate.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyDescription,        value:[MetadataResult.Key.description.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyLongDescription,    value:[MetadataResult.Key.longDescription.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyRating,             value:[MetadataResult.Key.rating.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyStudio,             value:[MetadataResult.Key.studio.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyCast,               value:[MetadataResult.Key.cast.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyDirector,           value:[MetadataResult.Key.director.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyProducer,           value:[MetadataResult.Key.producers.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyScreenwriters,      value:[MetadataResult.Key.screenwriters.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyCopyright,          value:[MetadataResult.Key.copyright.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyContentID,          value:[MetadataResult.Key.contentID.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyAccountCountry,     value:[MetadataResult.Key.iTunesCountry.token]),
                      MetadataResultMapItem(key: MP42MetadataKeyExecProducer,       value:[MetadataResult.Key.executiveProducer.token])]

        return MetadataResultMap(items: items, type: .movie)
    }

    public static var tvShowDefaultMap: MetadataResultMap {
        let items = [MetadataResultMapItem(key: MP42MetadataKeyName,           value:[MetadataResult.Key.name.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyArtist,         value:[MetadataResult.Key.seriesName.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyAlbumArtist,    value:[MetadataResult.Key.seriesName.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyAlbum,          value:[MetadataResult.Key.seriesName.token, Token(text: ", Season ", isPlaceholder: false), MetadataResult.Key.season.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyComposer,       value:[MetadataResult.Key.composer.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyUserGenre,      value:[MetadataResult.Key.genre.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyReleaseDate,    value:[MetadataResult.Key.releaseDate.token]),

                     MetadataResultMapItem(key: MP42MetadataKeyTrackNumber,        value:[MetadataResult.Key.trackNumber.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyDiscNumber,         value:[MetadataResult.Key.diskNumber.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVShow,             value:[MetadataResult.Key.seriesName.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVEpisodeNumber,    value:[MetadataResult.Key.episodeNumber.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVNetwork,          value:[MetadataResult.Key.network.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVEpisodeID,        value:[MetadataResult.Key.episodeID.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyTVSeason,           value:[MetadataResult.Key.season.token]),

                     MetadataResultMapItem(key: MP42MetadataKeyDescription,        value:[MetadataResult.Key.description.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyLongDescription,    value:[MetadataResult.Key.longDescription.token]),
                     MetadataResultMapItem(key: MP42MetadataKeySeriesDescription,  value:[MetadataResult.Key.seriesDescription.token]),

                     MetadataResultMapItem(key: MP42MetadataKeyRating,             value:[MetadataResult.Key.rating.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyStudio,             value:[MetadataResult.Key.studio.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyCast,               value:[MetadataResult.Key.cast.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyDirector,           value:[MetadataResult.Key.director.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyProducer,           value:[MetadataResult.Key.producers.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyScreenwriters,      value:[MetadataResult.Key.screenwriters.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyExecProducer,       value:[MetadataResult.Key.executiveProducer.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyCopyright,          value:[MetadataResult.Key.copyright.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyContentID,          value:[MetadataResult.Key.contentID.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyArtistID,           value:[MetadataResult.Key.artistID.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyPlaylistID,         value:[MetadataResult.Key.playlistID.token]),
                     MetadataResultMapItem(key: MP42MetadataKeyAccountCountry,     value:[MetadataResult.Key.iTunesCountry.token])]

        return MetadataResultMap(items: items, type: .tvShow)
    }

    public var items: [MetadataResultMapItem]
    public let type: MetadataType

    init(items: [MetadataResultMapItem], type: MetadataType) {
        self.items = items
        self.type = type
    }
}

extension UserDefaults {

    func map(forKey defaultName: String) -> MetadataResultMap? {
        let decoder = JSONDecoder()

        guard let jsonData = self.data(forKey: defaultName),
            let decoded = try? decoder.decode(MetadataResultMap.self, from: jsonData) else { return nil }

        return decoded
    }

    func set(_ map: MetadataResultMap, forKey defaultName: String) {
        let encoder = JSONEncoder()
        let jsonData = try? encoder.encode(map)
        self.set(jsonData, forKey: defaultName)
    }

}

// MARK: Old style map, to be removed next year

@objc(SBMetadataResultMapItem) private class SBMetadataResultMapItem : NSObject, NSSecureCoding {

    let key: String
    let value: [String]

    // MARK: NSSecureCoding

    static var supportsSecureCoding: Bool { return true }

    func encode(with aCoder: NSCoder) {}

    required init?(coder aDecoder: NSCoder) {
        guard let key = aDecoder.decodeObject(of: NSString.self, forKey: "key") as String?,
            let value = aDecoder.decodeObject(of: [NSArray.self, NSString.self], forKey: "value") as? [String]
            else { return nil }
        self.key = key
        self.value = value
    }

}

@objc(SBMetadataResultMap) private class SBMetadataResultMap : NSObject, NSSecureCoding {

    var items: [SBMetadataResultMapItem]
    let type: MetadataType

    // MARK: NSSecureCoding

    static var supportsSecureCoding: Bool { return true }

    func encode(with aCoder: NSCoder) {}

    required init?(coder aDecoder: NSCoder) {
        guard let items = aDecoder.decodeObject(of: [NSArray.self, SBMetadataResultMapItem.self], forKey: "items") as? [SBMetadataResultMapItem],
            let type = MetadataType(rawValue: Int(aDecoder.decodeInt32(forKey: "type")))
            else { return nil }
        self.items = items
        self.type = type
    }

}

extension UserDefaults {

    func mapFromOldStylePrefs(forKey defaultName: String) -> MetadataResultMap? {
        guard let data = self.data(forKey: defaultName) else { return nil }

        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        unarchiver.requiresSecureCoding = true

        if let oldMap = unarchiver.decodeObject(of: SBMetadataResultMap.self, forKey: NSKeyedArchiveRootObjectKey) {

            let items = oldMap.items.map { (item: SBMetadataResultMapItem) -> MetadataResultMapItem in
                let tokens = item.value.map { Token(text: $0, isPlaceholder: MetadataResult.Key(rawValue: $0) != nil)}
                return MetadataResultMapItem(key: item.key, value: tokens)
            }
            let map = MetadataResultMap(items: items, type: oldMap.type)

            return map
        }

        return nil
    }

}

