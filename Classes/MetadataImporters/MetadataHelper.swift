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

// MARK: - Image

extension Array where Element == RemoteImage {
    func toClass() -> [SBRemoteImage] {
        return self.map { $0.toClass() }
    }
}

extension SBRemoteImage {
    func toStruct() -> RemoteImage {
        return RemoteImage(url: self.url, thumbURL: self.thumbURL, service: self.service, type: self.type)
    }
}

extension Array where Element == SBRemoteImage {
    func toStruct() -> [RemoteImage] {
        return self.map { $0.toStruct() }
    }
}

public struct RemoteImage {
    let url: URL
    let thumbURL: URL
    let service: String
    let type: String

    public func toClass() -> SBRemoteImage {
        return SBRemoteImage(url: url, thumbURL: thumbURL, service: service, type: type)
    }
}

// MARK: - Filename

public enum FilenameInfo {
    case movie(title: String)
    case tvShow(seriesName: String, season: Int?, episode: Int?)

    public var isMovie: Bool { get {
            switch self {
            case .movie:
                return true
            case .tvShow:
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

private func parseAnimeFilename(_ filename: String) -> FilenameInfo? {

    guard let regex = try? NSRegularExpression(pattern: "^\\[(.+)\\](?:(?:\\s|_)+)?([^()]+)(?:(?:\\s|_)+)(?:(?:-\\s|-_|Ep)+)([0-9]+)", options: [.caseInsensitive]) else { return nil }

    var result: FilenameInfo?

    regex.enumerateMatches(in: filename, options: [],
                           range: NSRange(filename.startIndex..., in: filename)) {
                            (match, flags, stop) in

                            if let seriesNameRange = match?.range(at: 2), let episodeRange = match?.range(at: 3) {
                                let seriesName = (filename as NSString).substring(with: seriesNameRange)
                                let episode = Int((filename as NSString).substring(with: episodeRange))

                                if seriesName.count > 0 {
                                    result = FilenameInfo.tvShow(seriesName: seriesName, season: 1, episode: episode)
                                }
                            }
    }

    return result
}

private func parseFilename(_ filename: String) -> FilenameInfo? {
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
    let lines = outputString.components(separatedBy: "\n")

    if lines.count > 0 {
        if lines.first == "tv" && lines.count >= 4 {
            let newSeriesName = lines[1].replacingOccurrences(of: ".", with: " ")
            return FilenameInfo.tvShow(seriesName: newSeriesName, season: Int(lines[2]), episode: Int(lines[3]))
        }
        else if lines.first == "movie" && lines.count >= 2 {
            let newTitle = lines[1].replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "[", with: " ")
            .replacingOccurrences(of: "]", with: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return FilenameInfo.movie(title: newTitle)
        }
    }

    return nil
}

extension String {

    func parsedAsFilename() -> FilenameInfo? {
        if let parsed = parseAnimeFilename(self) {
            return parsed
        }
        else if let parsed = parseFilename(self) {
            return parsed
        }
        return nil
    }
}
