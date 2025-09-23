//
//  MetadataResult.swift
//  Subler
//
//  Created by Damiano Galassi on 08/08/2017.
//

import Foundation
import MP42Foundation

// MARK: - Image

public enum ArtworkSize : Int, CustomStringConvertible {
    public var description: String {
        switch self {
        case .standard:
            return "standard"
        case .square:
            return "square"
        case .rectangle:
            return "rectangle"
        case .vertical:
            return "vertical"
        case .fullscreen:
            return "fullscreen"
        case .widescreen:
            return "widescreen"
        case .maxres:
            return "maxres"
        case .low:
            return "low"
        case .medium:
            return "medium"
        case .high:
            return "high"
        case .`default`:
            return "default"
        }
    }

    case standard
    case square
    case rectangle
    case vertical
    case fullscreen
    case widescreen
    case maxres
    case low
    case medium
    case high
    case `default`
}

public enum ArtworkType : Int, CustomStringConvertible {
    public var description: String {
        switch self {
        case .poster:
            return "poster"
        case .season:
            return "season"
        case .episode:
            return "episode"
        case .backdrop:
            return "backdrop"
        case .person:
            return "person"

        case .none:
            return NSLocalizedString("None", comment: "Queue metadata search artwork type")
        }
    }

    public var isMovieType: Bool {
        switch self {
        case .poster, .backdrop:
            return true
        default:
            return false
        }
    }

    case poster
    case season
    case episode
    case backdrop
    case person = 5
    case none = 4
}

public struct Artwork: Equatable, Hashable {
    public let url: URL
    public let thumbURL: URL
    public let service: String
    public let type: ArtworkType
    public let size: ArtworkSize

    public static func == (lhs: Artwork, rhs: Artwork) -> Bool {
        return lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    public static func unique(artworks: [Artwork]) -> [Artwork] {
        var uniques = [Artwork]()
        for artwork in artworks {
            if !uniques.contains(artwork) {
                uniques.append(artwork)
            }
        }
        return uniques
    }
}

public enum MediaKind: Int {
    case tvShow = 10
    case movie = 9

    public var description: String {
        switch self {
        case .movie:
            return "Movie"
        case .tvShow:
            return "TV"
        }
    }
}

private let localizedKeys: [MetadataResult.Key: String] = [
    .name             : NSLocalizedString("Name", comment: "nil"),
    .composer         : NSLocalizedString("Composer", comment: "nil"),
    .genre            : NSLocalizedString("Genre", comment: "nil"),
    .releaseDate      : NSLocalizedString("Release Date", comment: "nil"),
    .description      : NSLocalizedString("Description", comment: "nil"),
    .longDescription  : NSLocalizedString("Long Description", comment: "nil"),
    .rating           : NSLocalizedString("Rating", comment: "nil"),
    .studio           : NSLocalizedString("Studio", comment: "nil"),
    .cast             : NSLocalizedString("Cast", comment: "nil"),
    .director         : NSLocalizedString("Director", comment: "nil"),
    .producers        : NSLocalizedString("Producers", comment: "nil"),
    .screenwriters    : NSLocalizedString("Screenwriters", comment: "nil"),
    .executiveProducer: NSLocalizedString("Executive Producer", comment: "nil"),
    .copyright        : NSLocalizedString("Copyright", comment: "nil"),

    .contentID        : NSLocalizedString("contentID", comment: "nil"),
    .artistID         : NSLocalizedString("artistID", comment: "nil"),
    .playlistID       : NSLocalizedString("playlistID", comment: "nil"),
    .iTunesCountry    : NSLocalizedString("iTunes Country", comment: "nil"),
    .iTunesURL        : NSLocalizedString("iTunes URL", comment: "nil"),

    .seriesName       : NSLocalizedString("Series Name", comment: "nil"),
    .seriesDescription: NSLocalizedString("Series Description", comment: "nil"),
    .trackNumber      : NSLocalizedString("Track #", comment: "nil"),
    .diskNumber       : NSLocalizedString("Disk #", comment: "nil"),
    .episodeNumber    : NSLocalizedString("Episode #", comment: "nil"),
    .episodeID        : NSLocalizedString("Episode ID", comment: "nil"),
    .season           : NSLocalizedString("Season", comment: "nil"),
    .network          : NSLocalizedString("Network", comment: "nil"),

    .serviceContentID  : NSLocalizedString("Service Content ID", comment: "nil"),
    .serviceAdditionalContentID : NSLocalizedString("Service Additional Content ID", comment: "nil"),
    .serviceEpisodeID : NSLocalizedString("Service Episode ID", comment: "nil")
]

public final class MetadataResult {

    public enum Key: String {
        // Common Keys
        case name               = "{Name}"
        case composer           = "{Composer}"
        case genre              = "{Genre}"
        case releaseDate        = "{Release Date}"
        case description        = "{Description}"
        case longDescription    = "{Long Description}"
        case rating             = "{Rating}"
        case studio             = "{Studio}"
        case cast               = "{Cast}"
        case director           = "{Director}"
        case producers          = "{Producers}"
        case screenwriters      = "{Screenwriters}"
        case executiveProducer  = "{Executive Producer}"
        case copyright          = "{Copyright}"

        case mediaKind          = "{MediaKind}"
        case contentRating      = "{ContentRating}"

        // iTunes Keys
        case contentID          = "{contentID}"
        case artistID           = "{artistID}"
        case playlistID         = "{playlistID}"
        case iTunesCountry      = "{iTunes Country}"
        case iTunesURL          = "{iTunes URL}"

        // TV Show Keys
        case seriesName         = "{Series Name}"
        case seriesDescription  = "{Series Description}"
        case trackNumber        = "{Track #}"
        case diskNumber         = "{Disk #}"
        case episodeNumber      = "{Episode #}"
        case episodeID          = "{Episode ID}"
        case season             = "{Season}"
        case network            = "{Network}"

        // Services internal IDs
        case serviceContentID             = "{ServiceSeriesID}"
        case serviceAdditionalContentID   = "{AdditionalServiceSeriesID}"
        case serviceEpisodeID             = "{ServiceEpisodeID}"

        fileprivate static var movieKeys: [Key] {
            return [.name,
                    .composer,
                    .genre,
                    .releaseDate,
                    .description,
                    .longDescription,
                    .rating,
                    .studio,
                    .cast,
                    .director,
                    .producers,
                    .screenwriters,
                    .executiveProducer,
                    .copyright,
                    .contentID,
                    .artistID,
                    .iTunesCountry,

                    .serviceContentID,
                    .serviceAdditionalContentID,
                    .serviceEpisodeID]
        }

        fileprivate static var tvShowKeys: [Key] {
            return [.name,
                    .seriesName,
                    .composer,
                    .genre,
                    .releaseDate,

                    .trackNumber,
                    .diskNumber,
                    .episodeNumber,
                    .network,
                    .episodeID,
                    .season,

                    .description,
                    .longDescription,
                    .seriesDescription,

                    .rating,
                    .studio,
                    .cast,
                    .director,
                    .producers,
                    .screenwriters,
                    .executiveProducer,
                    .copyright,
                    .contentID,
                    .artistID,
                    .playlistID,
                    .iTunesCountry,

                    .serviceContentID,
                    .serviceAdditionalContentID,
                    .serviceEpisodeID
            ]
        }

        fileprivate static var sortedKeys: [Key] {
            return [.name,
                    .seriesName,
                    .composer,
                    .genre,
                    .releaseDate,

                    .trackNumber,
                    .diskNumber,
                    .episodeNumber,
                    .network,
                    .episodeID,
                    .season,

                    .description,
                    .longDescription,
                    .seriesDescription,

                    .rating,
                    .studio,
                    .cast,
                    .director,
                    .producers,
                    .screenwriters,
                    .executiveProducer,
                    .copyright,
                    .contentID,
                    .artistID,
                    .playlistID,

                    .iTunesURL,
                    .iTunesCountry,

                    .serviceContentID,
                    .serviceAdditionalContentID,
                    .serviceEpisodeID
            ]
        }


        public var localizedDisplayName: String {
            return localizedKeys[self] ?? "Null"
        }

        public var token: Token {
            return Token(text: self.rawValue)
        }

        public static var movieKeysStrings: [String] {
            return Key.movieKeys.map { $0.rawValue }
        }

        public static var tvShowKeysStrings: [String] {
            return Key.tvShowKeys.map { $0.rawValue }
        }

        public static func localizedDisplayName(key: String) -> String {
            return Key(rawValue: key)?.localizedDisplayName ?? key
        }

    }

    private var dictionary: [Key:Any]
    public var mediaKind: MediaKind
    public var contentRating: Int
    public var remoteArtworks: [Artwork]
    public var artworks: [MP42Image]

    init() {
        self.dictionary = [:]
        self.remoteArtworks = []
        self.artworks = []
        self.mediaKind = .movie
        self.contentRating = 0
    }

    subscript(key: Key) -> Any? {
        get {
            return dictionary[key]
        }
        set (newValue) {
            dictionary[key] = newValue
        }
    }

    lazy var orderedKeys: [Key] = {
        let sortedKeys = Key.sortedKeys
        return Array(dictionary.keys).sorted(by: { (key1: Key, key2: Key) -> Bool in
            if let index1 = sortedKeys.firstIndex(of: key1), let index2 = sortedKeys.firstIndex(of: key2) {
                return index1 < index2
            }
            return key1 != Key.serviceContentID && key1 != Key.serviceEpisodeID
        })
    }()

    public var count: Int {
        return dictionary.count
    }

    public func merge(result: MetadataResult) {
        dictionary.merge(result.dictionary) { (_, new) in new }
    }

    private func truncate(string: String, to index: Int) -> String {
        let words = string.split(separator: " ")
        var accumulatedCounts = words.map { $0.count + 1 }
        for index in 1..<accumulatedCounts.count {
            accumulatedCounts[index] += accumulatedCounts[index - 1]
        }
        let endIndex = accumulatedCounts.filter { $0 < index }.endIndex
        return words[0..<endIndex].joined(separator: " ") + "…"
    }

    public func mappedMetadata(to map: MetadataResultMap, keepEmptyKeys: Bool) -> MP42Metadata {
        let metadata = MP42Metadata()

        if dictionary[.description] == nil, let longDesc = dictionary[.longDescription] as? String {
            if longDesc.count > 254 {
                dictionary[.description] = truncate(string: longDesc, to: 254)
            } else {
                dictionary[.description] = longDesc
            }
        }

        metadata.addItems(map.items.compactMap {
            let value = $0.value.reduce("", {
                if let key = Key(rawValue: $1.text) {
                    if let value = dictionary[key] {
                        return $0 + $1.format(text: "\(value)")
                    }
                    return $0
                }
                else {
                    return $0 + $1.text
                }
            })
            return value.isEmpty == false || keepEmptyKeys ? MP42MetadataItem(identifier: $0.key,
                                                                              value: value as NSCopying & NSObjectProtocol,
                                                                              dataType: .unspecified, extendedLanguageTag: nil): nil
        })

        metadata.addItems(artworks.map {
            MP42MetadataItem(identifier: MP42MetadataKeyCoverArt,value: $0,
                             dataType: .image, extendedLanguageTag: nil)
        })

        let mediaKind = MP42MetadataItem(identifier: MP42MetadataKeyMediaKind,
                                         value: NSNumber(value: self.mediaKind.rawValue),
                                         dataType: .integer,
                                         extendedLanguageTag: nil)
        metadata.addItem(mediaKind)

        if contentRating > 0 || keepEmptyKeys {
            let contentRating = MP42MetadataItem(identifier: MP42MetadataKeyContentRating,
                                             value: NSNumber(value: self.contentRating),
                                             dataType: .integer,
                                             extendedLanguageTag: nil)
            metadata.addItem(contentRating)
        }

        return metadata
    }

}
