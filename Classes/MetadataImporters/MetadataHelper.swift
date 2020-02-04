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

private func parseFilename(_ filename: String) -> MetadataSearchTerms? {
    guard let path = Bundle.main.path(forResource: "ParseFilename", ofType: "") else { return nil }

    let stdOut = Pipe()
    let stdOutWrite = stdOut.fileHandleForWriting

    // Use the ParseFilename perl script
    let task = Process()
    task.launchPath = "/usr/bin/perl"
    task.arguments = ["-I\(path)/lib", "\(path)/ParseFilename.pl", filename]
    task.standardOutput = stdOutWrite

    task.launch()
    task.waitUntilExit()
    stdOutWrite.closeFile()

    let outputData = stdOut.fileHandleForReading.readDataToEndOfFile()
    guard let outputString = String(data: outputData, encoding: .utf8) else { return nil }
    let lines = outputString.split(separator: "\n")

    if lines.isEmpty == false {
        if lines.first == "tv" && lines.count >= 4 {
            let newSeriesName = lines[1].isEmpty == false ? lines[1].replacingOccurrences(of: ".", with: " ") : filename
            return MetadataSearchTerms.tvShow(seriesName: newSeriesName, season: Int(lines[2]), episode: Int(lines[3]))
        }
        else if lines.first == "movie" && lines.count >= 2 {
            let newTitle = lines[1].replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "[", with: " ")
            .replacingOccurrences(of: "]", with: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return MetadataSearchTerms.movie(title: newTitle)
        }
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
