//
//  PresetManager.swift
//  Subler
//
//  Created by Damiano Galassi on 21/08/2017.
//

import Foundation

extension PresetManager.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadyExists:
            return NSLocalizedString("A preset already exists with the same name.", comment: "")
        }
    }
    public var recoverySuggestion: String? {
        switch self {
        case .alreadyExists:
            return NSLocalizedString("Please enter a different name for the preset.", comment: "")
        }
    }
}

@objc(SBPresetManager) final class PresetManager: NSObject {
    @objc static let shared = PresetManager()

    let updateNotification = Notification.Name(rawValue: "SBPresetManagerUpdatedNotification")
    var presets: [Preset]

    @objc var metadataPresets: [MetadataPreset] {
        return presets.compactMap { $0 as? MetadataPreset }
    }

    var queuePresets: [QueuePreset] {
        return presets.compactMap { $0 as? QueuePreset }
    }

    private override init() {
        self.presets = Array()
        super.init()
        try? load()
    }

    // MARK: management

    enum Error : Swift.Error {
        case alreadyExists
    }

    @objc func append(newElement: Preset) throws {
        if item(name: newElement.title) != nil {
            throw Error.alreadyExists
        }
        presets.append(newElement)
        sort()
        postNotification()
        try save(preset: newElement)
    }

    func remove(at index: Int) {
        let preset = presets[index]
        try? FileManager.default.removeItem(at: preset.fileURL)
        presets.remove(at: index)
        postNotification()
    }

    func remove(item: Preset) {
        if let index = presets.index(where: { $0 === item }) {
            remove(at: index)
        }
    }

    @objc func item(name: String) -> Preset? {
        return presets.filter { $0.title == name }.first
    }

    private func sort() {
        presets.sort { return $0.title.localizedCompare($1.title) == ComparisonResult.orderedAscending }
    }

    private func postNotification() {
        NotificationCenter.default.post(name: updateNotification, object: self)
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

    private func migratePreset(at fileURL: URL) throws {
        let manager = FileManager.default
        guard let url = appSupportURL() else { return }

        let migrated = url.appendingPathComponent("migrated", isDirectory: true)
        try manager.createDirectory(at: migrated, withIntermediateDirectories: true, attributes: [:])

        let migratedFileURL = migrated.appendingPathComponent(fileURL.lastPathComponent, isDirectory: false)
        try manager.moveItem(at: fileURL, to: migratedFileURL)
    }

    private func load(fileURL: URL) throws -> Preset {
        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
        if resourceValues.isDirectory == false, let version = version(of: fileURL) {
            let data = try Data(contentsOf: fileURL)
            let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
            unarchiver.requiresSecureCoding = true
            defer { unarchiver.finishDecoding() }

            if version == 1, let preset = unarchiver.decodeObject(of: [MP42Metadata.self], forKey: NSKeyedArchiveRootObjectKey) as? MP42Metadata {
                let newPreset = MetadataPreset(title: preset.presetName, metadata: preset, replaceArtworks: true, replaceAnnotations: false)
                try migratePreset(at: fileURL)
                try save(preset: newPreset)
                return newPreset
            }
            else if  let preset = unarchiver.decodeObject(of: [MetadataPreset.self], forKey: NSKeyedArchiveRootObjectKey) as? MetadataPreset {
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

    @objc func save() throws {
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
