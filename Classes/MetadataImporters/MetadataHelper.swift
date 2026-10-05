//
//  MetadataHelper.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Foundation

// MARK: - Filename

public enum MetadataSearchTerms {
    case none
    case movie(title: String)
    case tvShow(seriesName: String, season: Int?, episode: Int?)

    public var isMovie: Bool { get {
            switch self {
            case .movie:
                return true
            case .tvShow, .none:
                return false
            }
        }
    }

    public var isTVShow: Bool {
        get {
            return !self.isMovie
        }
    }
}

private func parseAnimeFilename(_ filename: String) -> MetadataSearchTerms? {

    guard let regex = try? NSRegularExpression(pattern: "^\\[(.+)\\](?:(?:\\s|_)+)?([^()]+)(?:(?:\\s|_)+)(?:(?:-\\s|-_|Ep)+)([0-9]+)", options: [.caseInsensitive]) else { return nil }

    var result: MetadataSearchTerms?

    regex.enumerateMatches(in: filename, options: [],
                           range: NSRange(filename.startIndex..., in: filename)) {
                            (match, flags, stop) in

                            if let seriesNameRange = match?.range(at: 2), let episodeRange = match?.range(at: 3) {
                                let seriesName = (filename as NSString).substring(with: seriesNameRange)
                                let episode = Int((filename as NSString).substring(with: episodeRange))

                                if seriesName.isEmpty == false {
                                    result = MetadataSearchTerms.tvShow(seriesName: seriesName, season: 1, episode: episode)
                                }
                            }
    }

    return result
}

// Formerly invoked the bundled ParseFilename perl script; now calls the
// native Swift port in VideoFilename.swift. Result handling matches the
// original perl-output parsing: a TV match is only returned when series
// name, season and episode were all found (the perl pipeline dropped empty
// output lines, so partial matches fell through to nil), and a movie match
// requires a non-empty title.
private func parseFilename(_ filename: String) -> MetadataSearchTerms? {
    let file = ParsedVideoFilename.parse(filename)

    if let name = file.name, name.isEmpty == false,
       let season = file.seasonInt, let episode = file.episodeInt {
        let newSeriesName = name.replacingOccurrences(of: ".", with: " ")
        return MetadataSearchTerms.tvShow(seriesName: newSeriesName, season: season, episode: episode)
    }
    else if file.isEpisode {
        // Episode without a usable series name or season; like the original
        // pipeline, do not guess.
        return nil
    }
    else if let movie = file.movie, movie.isEmpty == false {
        let newTitle = movie.replacingOccurrences(of: ".", with: " ")
        .replacingOccurrences(of: "(", with: " ")
        .replacingOccurrences(of: ")", with: " ")
        .replacingOccurrences(of: "[", with: " ")
        .replacingOccurrences(of: "]", with: " ")
        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return MetadataSearchTerms.movie(title: newTitle)
    }

    return nil
}

extension String {

    func parsedAsFilename() -> MetadataSearchTerms {
        if let parsed = parseAnimeFilename(self) {
            return parsed
        }
        else if let parsed = parseFilename(self) {
            return parsed
        }
        return .none
    }

    func trimmingWhitespacesAndNewlinews() -> String {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
