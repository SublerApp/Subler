//
//  Logger.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Foundation
import MP42Foundation

final class Logger : NSObject, MP42Logging {

    var delegate: MP42Logging?

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
            return "\(p.tm_hour):\(p.tm_min):\(p.tm_sec)"
        } else {
            return ""
        }
    }

    func write(toLog string: String) {
        queue.sync {
            let output = "\(currentTime()) \(string)\n"

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


}
