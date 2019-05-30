//
//  OCRManager.swift
//  Subler
//
//  Created by Damiano Galassi on 30/05/2019.
//

import Foundation
import MP42Foundation

final class OCRLanguage {

    enum Status {
        case available
        case downloading
        case downloaded
    }

    private(set) var status: Status

    let langCode: String
    let name: String

    init(langCode: String, name: String) {
        self.status = .available
        self.langCode = langCode
        self.name = name
    }

    var displayName: String {
        get {
            return OCRLanguage.langManager.localizedLang(forExtendedTag: langCode)
        }
    }

    fileprivate func checkIfDownloaded(_ to: URL) {
        if (FileManager.default.fileExists(atPath: to.appendingPathComponent(name, isDirectory: false).path)) {
            status = .downloaded
        } else {
            status = .available
        }
    }

    private var task: URLSessionDownloadTask?

    fileprivate func startDownload(from remoteURL: URL, to localURL: URL, completionHandler: @escaping (Bool) -> Void) -> URLSessionTask? {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        let request = URLRequest(url: remoteURL.appendingPathComponent(name))

        let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
            if let tempLocalUrl = tempLocalUrl, error == nil {
                // Success
//                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
//                    print("Success: \(statusCode)")
//                }

                do {
                    try FileManager.default.copyItem(at: tempLocalUrl, to: localURL.appendingPathComponent(self.name, isDirectory: false))
                    self.status = .downloaded
                    self.task = nil
                    completionHandler(true)
                } catch {
                    self.status = . available
                    self.task = nil
                    completionHandler(false)
//                    print("error writing file \(localURL) : \(writeError)")
                }

            } else {
                self.status = .available
                self.task = nil
                completionHandler(false)
//                print("Failure: \(String(describing: error?.localizedDescription))")
            }
        }

        self.task = task
        self.status = .downloading

        task.resume()
        return task
    }

    fileprivate func cancel() {
        guard let task = task else { return }
        task.cancel()
    }

    fileprivate func remove(_ from: URL) throws {
        try FileManager.default.removeItem(at: from.appendingPathComponent(name, isDirectory: false))
        status = .available
    }

    private static let langManager = MP42Languages.defaultManager
}

final class OCRManager {
    static let shared = OCRManager()

    static let updateNotification = Notification.Name(rawValue: "OCRManagerUpdatedNotification")

    let languages: [OCRLanguage] = [OCRLanguage(langCode: "af", name: "afr.traineddata"),
                                    OCRLanguage(langCode: "am", name: "amh.traineddata"),
                                    OCRLanguage(langCode: "ar", name: "ara.traineddata"),
                                    OCRLanguage(langCode: "as", name: "asm.traineddata"),
                                    OCRLanguage(langCode: "it", name: "ita.traineddata")]

    private init() {
        try? load()
    }

    // MARK: management

    private func postNotification() {
        NotificationCenter.default.post(name: OCRManager.updateNotification, object: self)
    }

    private func destinationURL() -> URL? {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Subler", isDirectory: true).appendingPathComponent("tessdata", isDirectory: true)
    }

    private func baseURL() -> URL? {
        return URL(string: "https://github.com/tesseract-ocr/tessdata_fast/raw/master/")
    }

    func download(item: OCRLanguage) {
        if let baseURL = baseURL(), let destURL = destinationURL() {
            _ = item.startDownload(from: baseURL, to: destURL, completionHandler: { _ in self.postNotification() })
            postNotification()
        }
    }

    func cancelDownload(item: OCRLanguage) {
        item.cancel()
    }

    func removeDownload(item: OCRLanguage) throws {
        if let destURL = destinationURL() {
            try item.remove(destURL)
            postNotification()
        }
    }

    // MARK: read/write

    private func load() throws {
        if let destinationURL = destinationURL() {
            languages.forEach { $0.checkIfDownloaded(destinationURL) }
        }
    }

}
