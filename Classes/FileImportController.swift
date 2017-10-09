//
//  FileImportController.swift
//  Subler
//
//  Created by Damiano Galassi on 09/10/2017.
//

import Cocoa

protocol FileImportControllerDelegate : AnyObject {
    func didSelect(tracks: [MP42Track], metadata: MP42Metadata?)
}

class FileImportController: NSWindowController {

    private let fileURLs: [URL]
    private let fileImporters: [MP42FileImporter]

    private weak var delegate: FileImportControllerDelegate?

    init(fileURLs: [URL], delegate: FileImportControllerDelegate) throws {
        self.fileURLs = fileURLs
        self.delegate = delegate

        var tracks: [MP42Track] = Array()

        self.fileImporters = fileURLs.flatMap {
            let importer = MP42FileImporter(url: $0, error: nil)
            tracks.append(contentsOf: importer.tracks)
            return importer
        }

        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

}
