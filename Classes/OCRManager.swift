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

    fileprivate init(langCode: String, name: String) {
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

    fileprivate func startDownload(from remoteURL: URL, to localURL: URL, completionHandler: @escaping (Result<URL, Error>) -> Void) -> URLSessionTask? {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        let request = URLRequest(url: remoteURL.appendingPathComponent(name))

        let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
            if let tempLocalUrl = tempLocalUrl, error == nil {
                // Success
                do {
                    let localCompleteURL = localURL.appendingPathComponent(self.name, isDirectory: false)
                    try FileManager.default.copyItem(at: tempLocalUrl, to: localCompleteURL)
                    self.status = .downloaded
                    self.task = nil
                    completionHandler(.success(localCompleteURL))
                } catch {
                    self.status = . available
                    self.task = nil
                    completionHandler(.failure(error))
                }

            } else if let error = error {
                self.status = .available
                self.task = nil
                completionHandler(.failure(error))
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
                                    OCRLanguage(langCode: "az", name: "aze.traineddata"),
                                    OCRLanguage(langCode: "az-Cyrl", name: "aze_cyrl.traineddata"),
                                    OCRLanguage(langCode: "be", name: "bel.traineddata"),
                                    OCRLanguage(langCode: "bn", name: "ben.traineddata"),
                                    OCRLanguage(langCode: "bo", name: "bod.traineddata"),
                                    OCRLanguage(langCode: "bs", name: "bos.traineddata"),
                                    OCRLanguage(langCode: "br", name: "bre.traineddata"),
                                    OCRLanguage(langCode: "bg", name: "bul.traineddata"),
                                    OCRLanguage(langCode: "ca", name: "cat.traineddata"),
                                    OCRLanguage(langCode: "ceb", name: "ceb.traineddata"),
                                    OCRLanguage(langCode: "cs", name: "ces.traineddata"),
                                    OCRLanguage(langCode: "zh-Hans", name: "chi_sim.traineddata"),
//                                    OCRLanguage(langCode: "chi_sim_vert", name: "chi_sim_vert.traineddata"),
                                    OCRLanguage(langCode: "zh-Hant", name: "chi_tra.traineddata"),
//                                    OCRLanguage(langCode: "chi_tra_vert", name: "chi_tra_vert.traineddata"),
                                    OCRLanguage(langCode: "chr", name: "chr.traineddata"),
                                    OCRLanguage(langCode: "co", name: "cos.traineddata"),
                                    OCRLanguage(langCode: "cy", name: "cym.traineddata"),
                                    OCRLanguage(langCode: "da", name: "dan.traineddata"),
                                    OCRLanguage(langCode: "de", name: "deu.traineddata"),
                                    OCRLanguage(langCode: "dv", name: "div.traineddata"),
                                    OCRLanguage(langCode: "dz", name: "dzo.traineddata"),
                                    OCRLanguage(langCode: "el", name: "ell.traineddata"),
                                    OCRLanguage(langCode: "en", name: "eng.traineddata"),
                                    OCRLanguage(langCode: "enm", name: "enm.traineddata"),
                                    OCRLanguage(langCode: "eo", name: "epo.traineddata"),
                                    OCRLanguage(langCode: "et", name: "est.traineddata"),
                                    OCRLanguage(langCode: "eu", name: "eus.traineddata"),
                                    OCRLanguage(langCode: "fo", name: "fao.traineddata"),
                                    OCRLanguage(langCode: "fa", name: "fas.traineddata"),
                                    OCRLanguage(langCode: "fil", name: "fil.traineddata"),
                                    OCRLanguage(langCode: "fi", name: "fin.traineddata"),
                                    OCRLanguage(langCode: "fr", name: "fra.traineddata"),
//                                    OCRLanguage(langCode: "frk", name: "frk.traineddata"),
                                    OCRLanguage(langCode: "frm", name: "frm.traineddata"),
                                    OCRLanguage(langCode: "fy", name: "fry.traineddata"),
                                    OCRLanguage(langCode: "gd", name: "gla.traineddata"),
                                    OCRLanguage(langCode: "ga", name: "gle.traineddata"),
                                    OCRLanguage(langCode: "gl", name: "glg.traineddata"),
                                    OCRLanguage(langCode: "grc", name: "grc.traineddata"),
                                    OCRLanguage(langCode: "gu", name: "guj.traineddata"),
                                    OCRLanguage(langCode: "ht", name: "hat.traineddata"),
                                    OCRLanguage(langCode: "he", name: "heb.traineddata"),
                                    OCRLanguage(langCode: "hi", name: "hin.traineddata"),
                                    OCRLanguage(langCode: "hr", name: "hrv.traineddata"),
                                    OCRLanguage(langCode: "hu", name: "hun.traineddata"),
                                    OCRLanguage(langCode: "hy", name: "hye.traineddata"),
                                    OCRLanguage(langCode: "iu", name: "iku.traineddata"),
                                    OCRLanguage(langCode: "id", name: "ind.traineddata"),
                                    OCRLanguage(langCode: "is", name: "isl.traineddata"),
                                    OCRLanguage(langCode: "it", name: "ita.traineddata"),
                                    OCRLanguage(langCode: "jv", name: "jav.traineddata"),
                                    OCRLanguage(langCode: "ja", name: "jpn.traineddata"),
//                                    OCRLanguage(langCode: "jpn_vert", name: "jpn_vert.traineddata"),
                                    OCRLanguage(langCode: "kn", name: "kan.traineddata"),
                                    OCRLanguage(langCode: "ka", name: "kat.traineddata"),
//                                    OCRLanguage(langCode: "kat_old", name: "kat_old.traineddata"),
                                    OCRLanguage(langCode: "kk", name: "kaz.traineddata"),
                                    OCRLanguage(langCode: "km", name: "khm.traineddata"),
                                    OCRLanguage(langCode: "ky", name: "kir.traineddata"),
                                    OCRLanguage(langCode: "ku", name: "kmr.traineddata"),
                                    OCRLanguage(langCode: "ko", name: "kor.traineddata"),
//                                    OCRLanguage(langCode: "kor_vert", name: "kor_vert.traineddata"),
                                    OCRLanguage(langCode: "lo", name: "lao.traineddata"),
                                    OCRLanguage(langCode: "la", name: "lat.traineddata"),
                                    OCRLanguage(langCode: "lv", name: "lav.traineddata"),
                                    OCRLanguage(langCode: "lt", name: "lit.traineddata"),
                                    OCRLanguage(langCode: "lb", name: "ltz.traineddata"),
                                    OCRLanguage(langCode: "ml", name: "mal.traineddata"),
                                    OCRLanguage(langCode: "mr", name: "mar.traineddata"),
                                    OCRLanguage(langCode: "mk", name: "mkd.traineddata"),
                                    OCRLanguage(langCode: "mt", name: "mlt.traineddata"),
                                    OCRLanguage(langCode: "mn", name: "mon.traineddata"),
                                    OCRLanguage(langCode: "mi", name: "mri.traineddata"),
                                    OCRLanguage(langCode: "ms", name: "msa.traineddata"),
                                    OCRLanguage(langCode: "my", name: "mya.traineddata"),
                                    OCRLanguage(langCode: "ne", name: "nep.traineddata"),
                                    OCRLanguage(langCode: "nl", name: "nld.traineddata"),
                                    OCRLanguage(langCode: "no", name: "nor.traineddata"),
                                    OCRLanguage(langCode: "oc", name: "oci.traineddata"),
                                    OCRLanguage(langCode: "or", name: "ori.traineddata"),
                                    OCRLanguage(langCode: "osd", name: "osd.traineddata"),
                                    OCRLanguage(langCode: "pa", name: "pan.traineddata"),
                                    OCRLanguage(langCode: "pl", name: "pol.traineddata"),
                                    OCRLanguage(langCode: "pt", name: "por.traineddata"),
                                    OCRLanguage(langCode: "ps", name: "pus.traineddata"),
                                    OCRLanguage(langCode: "qu", name: "que.traineddata"),
                                    OCRLanguage(langCode: "ro", name: "ron.traineddata"),
                                    OCRLanguage(langCode: "ru", name: "rus.traineddata"),
                                    OCRLanguage(langCode: "sa", name: "san.traineddata"),
                                    OCRLanguage(langCode: "si", name: "sin.traineddata"),
                                    OCRLanguage(langCode: "sk", name: "slk.traineddata"),
                                    OCRLanguage(langCode: "sl", name: "slv.traineddata"),
                                    OCRLanguage(langCode: "sd", name: "snd.traineddata"),
                                    OCRLanguage(langCode: "es", name: "spa.traineddata"),
//                                    OCRLanguage(langCode: "spa_old", name: "spa_old.traineddata"),
                                    OCRLanguage(langCode: "sq", name: "sqi.traineddata"),
                                    OCRLanguage(langCode: "sr", name: "srp.traineddata"),
                                    OCRLanguage(langCode: "sr-Latn", name: "srp_latn.traineddata"),
                                    OCRLanguage(langCode: "su", name: "sun.traineddata"),
                                    OCRLanguage(langCode: "sw", name: "swa.traineddata"),
                                    OCRLanguage(langCode: "sv", name: "swe.traineddata"),
                                    OCRLanguage(langCode: "syr", name: "syr.traineddata"),
                                    OCRLanguage(langCode: "ta", name: "tam.traineddata"),
                                    OCRLanguage(langCode: "tt", name: "tat.traineddata"),
                                    OCRLanguage(langCode: "te", name: "tel.traineddata"),
                                    OCRLanguage(langCode: "tg", name: "tgk.traineddata"),
                                    OCRLanguage(langCode: "th", name: "tha.traineddata"),
                                    OCRLanguage(langCode: "ti", name: "tir.traineddata"),
                                    OCRLanguage(langCode: "to", name: "ton.traineddata"),
                                    OCRLanguage(langCode: "tr", name: "tur.traineddata"),
                                    OCRLanguage(langCode: "ug", name: "uig.traineddata"),
                                    OCRLanguage(langCode: "uk", name: "ukr.traineddata"),
                                    OCRLanguage(langCode: "ur", name: "urd.traineddata"),
                                    OCRLanguage(langCode: "uz", name: "uzb.traineddata"),
                                    OCRLanguage(langCode: "uz-Cyrl", name: "uzb_cyrl.traineddata"),
                                    OCRLanguage(langCode: "vi", name: "vie.traineddata"),
                                    OCRLanguage(langCode: "yi", name: "yid.traineddata"),
                                    OCRLanguage(langCode: "yo", name: "yor.traineddata")]

    private init() {
        try? load()
    }

    // MARK: management

    private func postNotification() {
        NotificationCenter.default.post(name: OCRManager.updateNotification, object: self)
    }

    private lazy var destinationURL = {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Subler", isDirectory: true).appendingPathComponent("tessdata", isDirectory: true).appendingPathComponent("v4", isDirectory: true)
    }()

    private lazy var baseURL = {
        return URL(string: "https://github.com/tesseract-ocr/tessdata/raw/main/")
    }()

    func download(item: OCRLanguage) {
        if let baseURL = baseURL, let destURL = destinationURL {
            _ = item.startDownload(from: baseURL, to: destURL, completionHandler: { _ in self.postNotification() })
            postNotification()
        }
    }

    func cancelDownload(item: OCRLanguage) {
        item.cancel()
    }

    func removeDownload(item: OCRLanguage) throws {
        if let destURL = destinationURL {
            try item.remove(destURL)
            postNotification()
        }
    }

    // MARK: read/write

    private func load() throws {
        if let destinationURL = destinationURL {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: [:])
            languages.forEach { $0.checkIfDownloaded(destinationURL) }
        }
    }

}
