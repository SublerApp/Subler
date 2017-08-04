//
//  MetadataHelper.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Foundation

public protocol MetadataSearchTask {
    @discardableResult func runAsync() -> MetadataSearchTask
    @discardableResult func run() -> MetadataSearchTask
    func cancel()
}

class MetadataSearchInternalTask<T> : MetadataSearchTask {

    private var queue: DispatchQueue
    private var cancelled: Bool = false
    private let search: () -> T
    private let completionHandler: (T) -> Void

    init(search: @escaping @autoclosure () -> T, completionHandler: @escaping (T) -> Void) {
        self.search = search
        self.completionHandler = completionHandler
        self.queue = DispatchQueue(label: "SearchTaskQueue")
    }

    @discardableResult public func runAsync() -> MetadataSearchTask {
        DispatchQueue.global(priority: .background).async {
            self.run()
        }
        return self
    }

    @discardableResult public func run() -> MetadataSearchTask {
        let results = self.search()
        queue.sync {
            if self.cancelled == false {
                self.completionHandler(results)
            }
        }
        return self
    }

    public func cancel() {
        queue.sync {
            self.cancelled = true
        }
    }
}

public protocol MetadataSearchCancelToken {
    func cancel()
    var sessionTask: URLSessionTask? { get set }
}

// MARK: - Filename

enum FilenameType {
    case movie(title: String)
    case tvShow(seriesName: String, season: Int?, episode: Int?)
}

private func parseAnimeFilename(_ filename: String) -> FilenameType? {

    guard let regex = try? NSRegularExpression(pattern: "^\\[(.+)\\](?:(?:\\s|_)+)?([^()]+)(?:(?:\\s|_)+)(?:(?:-\\s|-_|Ep)+)([0-9]+)", options: [.caseInsensitive]) else { return nil }

    var result: FilenameType?

    regex.enumerateMatches(in: filename, options: [],
                           range: NSRange(filename.startIndex..., in: filename)) {
                            (match, flags, stop) in

                            if let seriesNameRange = match?.range(at: 2), let episodeRange = match?.range(at: 3) {
                                let seriesName = (filename as NSString).substring(with: seriesNameRange)
                                let episode = Int((filename as NSString).substring(with: episodeRange))

                                if seriesName.count > 0 {
                                    result = FilenameType.tvShow(seriesName: seriesName, season: 1, episode: episode)
                                }
                            }
    }

    return result
}

private func parseFilename(_ filename: String) -> FilenameType? {
    guard let path = Bundle(for: MP42File.self).path(forResource: "ParseFilename", ofType: "") else { return nil }

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
    let outputString = String(describing: outputData)
    let lines = outputString.components(separatedBy: "\n")

    if lines.count > 0 {
        if lines.first == "tv" && lines.count >= 4 {
            let newSeriesName = lines[1].replacingOccurrences(of: ".", with: " ")
            return FilenameType.tvShow(seriesName: newSeriesName, season: Int(lines[2]), episode: Int(lines[3]))
        }
        else if lines.first == "movie" && lines.count >= 2 {
            let newTitle = lines[1].replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "[", with: " ")
            .replacingOccurrences(of: "]", with: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return FilenameType.movie(title: newTitle)
        }
    }

    return nil
}

extension String {

    func parsedAsFilename() -> FilenameType? {
        if let parsed = parseAnimeFilename(self) {
            return parsed
        }
        else if let parsed = parseFilename(self) {
            return parsed
        }
        return nil
    }
}

// MARK: - URL Utilities

extension String {

    func urlEncoded() -> String {
        return self.precomposedStringWithCompatibilityMapping.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
    }

}
