//
//  PresetManager.swift
//  Subler
//
//  Created by Damiano Galassi on 21/08/2017.
//

import Foundation
import MP42Foundation

extension PresetManager.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadyExists:
            return NSLocalizedString("A preset already exists with the same name.", comment: "")
        case .emptyTitle:
            return NSLocalizedString("The preset name must not be empty.", comment: "")
        }
    }
    public var recoverySuggestion: String? {
        switch self {
        case .alreadyExists:
            return NSLocalizedString("Please enter a different name for the preset.", comment: "")
        case .emptyTitle:
            return NSLocalizedString("Please enter a name for the preset.", comment: "")
        }
    }
}

final class PresetManager {
    static let shared = PresetManager()

    static let updateNotification = Notification.Name(rawValue: "SBPresetManagerUpdatedNotification")

    private var presets: [Preset]

    var metadataPresets: [MetadataPreset] {
        return presets.compactMap { $0 as? MetadataPreset }
    }

    var queuePresets: [QueuePreset] {
        return presets.compactMap { $0 as? QueuePreset }
    }

    private init() {
        self.presets = []
        try? load()
    }

    // MARK: management

    enum Error : Swift.Error {
        case alreadyExists
        case emptyTitle
    }

    func append(newElement: Preset) throws {
        if newElement.title.isEmpty {
            throw Error.emptyTitle
        }
        if item(name: newElement.title) != nil {
            throw Error.alreadyExists
        }
        presets.append(newElement)
        sort()
        postNotification()
        try save(preset: newElement)
    }

    private func remove(at index: Int) throws {
        let preset = presets[index]
        try FileManager.default.removeItem(at: preset.fileURL)
        presets.remove(at: index)
        postNotification()
    }

    func remove(item: Preset) throws {
        if let index = presets.firstIndex(where: { $0 === item }) {
            try remove(at: index)
        }
    }

    func item(name: String) -> Preset? {
        return presets.first { $0.title == name }
    }

    private func sort() {
        presets.sort { return $0.title.localizedStandardCompare($1.title) == ComparisonResult.orderedAscending }
    }

    private func postNotification() {
        NotificationCenter.default.post(name: PresetManager.updateNotification, object: self)
    }

    // MARK: read/write

    private enum LoadError: Swift.Error {
        case unsupportedFile
    }

    private func appSupportURL() -> URL? {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Subler")
    }

    private func version(of fileURL: URL) -> Int? {
        switch fileURL.pathExtension {
        case "sbpreset":
            return 1
        case "sbpreset2":
            return 2
        default:
            return nil
        }
    }

    private func load(fileURL: URL) throws -> Preset {
        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
        if resourceValues.isDirectory == false, let version = version(of: fileURL) {
            let data = try Data(contentsOf: fileURL)
            let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
            unarchiver.requiresSecureCoding = true
            defer { unarchiver.finishDecoding() }

            if version == 2, let preset = try? unarchiver.decodeTopLevelObject(of: [MetadataPreset.self], forKey: NSKeyedArchiveRootObjectKey) as? MetadataPreset {
                return preset
            }
        }
        throw LoadError.unsupportedFile
    }

    private func load() throws {
        let manager = FileManager.default
        guard let url = appSupportURL(),
              let directoryEnumerator = manager.enumerator(at: url,
                                                           includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                                                           options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants],
                                                           errorHandler: nil)
        else { return }

        for case let fileURL as URL in directoryEnumerator {
            do {
                let preset = try load(fileURL: fileURL)
                presets.append(preset)
            }
            catch {}
        }
        sort()
    }

    private func save(preset: Preset) throws {
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.requiresSecureCoding = true
        archiver.encode(preset, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()

        try data.write(to: preset.fileURL, options: [.atomic])
        preset.changed = false
    }

    func save() throws {
        let manager = FileManager.default
        guard let url = appSupportURL() else { return }

        try manager.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])

        for preset in presets {
            if preset.changed {
                try save(preset: preset)
            }
        }
    }

}
