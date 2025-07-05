//
//  Logger.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Foundation
import MP42Foundation

final class Logger : NSObject, MP42Logging {

    enum Format: Int {
        case timeOnly = 0
        case dateAndTime = 1
    }

    static let shared = Logger(fileURL: defaultDestinationURL)

    var delegate: MP42Logging?
    var format: Format { Format(rawValue: Prefs.logFormat) ?? .timeOnly }

    private let fileURL: URL
    private let queue: DispatchQueue

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.queue = DispatchQueue(label: "org.subler.LogQueue")
    }

    private func currentTime() -> String {
        var currentTime = time(nil)
        if let localTime = localtime(&currentTime) {
            let p = localTime.pointee
            return String(format: "%02d:%02d:%02d", p.tm_hour, p.tm_min, p.tm_sec)
        } else {
            return ""
        }
    }

    private func currentDate() -> String {
        var currentTime = time(nil)
        if let localTime = localtime(&currentTime) {
            let p = localTime.pointee
            return String(format: "%04d-%02d-%02d", p.tm_year + 1900, p.tm_mon + 1, p.tm_mday)
        } else {
            return ""
        }
    }

    func write(toLog string: String) {
        queue.sync {
            let prefix: String
            switch format {
            case .timeOnly:
                prefix = currentTime()
            case .dateAndTime:
                prefix = "\(currentDate()) \(currentTime())"
            }
            let output = "\(prefix) \(string)\n"

            fileURL.withUnsafeFileSystemRepresentation {
                if let file = fopen($0, "a") {
                    fputs(output, file)
                    fclose(file)
                }
            }

            if let delegate = delegate {
                delegate.write(toLog: output)
            }
        }
    }

    func writeError(toLog error: Error) {
        write(toLog: error.localizedDescription)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static let defaultDestinationURL: URL = {
        appSupportURL().appendingPathComponent("debugLog.txt")
    }()

    private static func appSupportURL() -> URL {
        let fileManager = FileManager.default
        if let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Subler") {

            do {
                if fileManager.fileExists(atPath: url.path) == false {
                    try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
                }
            }
            catch _ {
                fatalError("Couldn't create the app support directory")
            }

            return url
        }
        else {
            fatalError("Couldn't find the app support directory")
        }
    }
}
