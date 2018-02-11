//
//  MP42FileAdditions.swift
//  Subler
//
//  Created by Damiano Galassi on 09/10/2017.
//

import Foundation

private extension String {
    func condensingWhitespace() -> String {
        return self.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

extension MP42File {

    enum TrackHDType : Int {
        case hd720p = 1
        case hd1080p = 2
    }

    var hdType: TrackHDType? {
        for track in tracks(withMediaType: kMP42MediaType_Video) as! [MP42VideoTrack] {
            if track.width > 1280 || track.height > 720 {
                return .hd1080p
            } else if track.width >= 960 && track.height >= 720 || track.width >= 1280 {
                return .hd720p
            }
        }
        return nil
    }

    func firstSourceURL() -> URL? {
        for track in tracks {
            if track.url != nil {
                return track.url
            }
        }
        return nil
    }

    func extractSearchTerms(fallbackURL: URL?) -> MetadataSearchTerms {
        if let tvShow = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyTVShow).first?.stringValue,
            let season = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyTVSeason).first?.numberValue?.intValue,
            let number = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyTVEpisodeNumber).first?.numberValue?.intValue,
            let mediaKind = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyMediaKind).first?.numberValue?.intValue,
            mediaKind == MetadataResult.MediaKindType.tvShow.rawValue {
            return MetadataSearchTerms.tvShow(seriesName: tvShow, season: season, episode: number)
        }
        else if let title = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyName).first?.stringValue,
            let _ = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyReleaseDate).first?.stringValue,
            let mediaKind = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyMediaKind).first?.numberValue?.intValue,
            mediaKind == MetadataResult.MediaKindType.movie.rawValue {
            return MetadataSearchTerms.movie(title: title)
        }
        else if let url = firstSourceURL() ?? fallbackURL {
            let parsed = url.lastPathComponent.parsedAsFilename()

            switch parsed {
            case .none:
                let title = url.deletingPathExtension().lastPathComponent
                return MetadataSearchTerms.movie(title: title)

            case .tvShow, .movie:
                return parsed
            }
        }
        return MetadataSearchTerms.none
    }

    private func outputNameFormat(mediaKind: Int) -> [String]? {
        if mediaKind == MetadataResult.MediaKindType.tvShow.rawValue {
            return UserDefaults.standard.stringArray(forKey: "SBTVShowFormat")
        } else if mediaKind == MetadataResult.MediaKindType.movie.rawValue {
            return UserDefaults.standard.stringArray(forKey: "SBMovieFormat")
        }
        return nil
    }

    // MARK: File name

    func preferredFileName() -> String? {
        if let mediaKind = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyMediaKind).first?.numberValue?.intValue,
            (mediaKind == MetadataResult.MediaKindType.tvShow.rawValue && UserDefaults.standard.bool(forKey: "SBSetTVShowFormat")) ||
                (mediaKind == MetadataResult.MediaKindType.movie.rawValue && UserDefaults.standard.bool(forKey: "SBSetMovieFormat")),
            let name = formattedFileName() {
            return name
        } else {
            return tracks.compactMap { $0.url }.first?.deletingPathExtension().lastPathComponent
        }
    }

    func formattedFileName() -> String? {
        guard let mediaKind = metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyMediaKind).first?.numberValue?.intValue,
              let format = outputNameFormat(mediaKind: mediaKind)
            else { return nil }

        let separators = CharacterSet(charactersIn: "{}")
        var name = ""

        for token in format {
            if token.hasPrefix("{") && token.hasSuffix("}") {
                let trimmedToken = token.trimmingCharacters(in: separators)
                let metadataItems = metadata.metadataItemsFiltered(byIdentifier: trimmedToken)

                if let string = metadataItems.first?.stringValue {
                    name.append(string)
                }
            } else {
                name.append(token)
            }
        }

        name = name.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "/", with: "-").condensingWhitespace()

        return name.isEmpty ? nil : name
    }
}
