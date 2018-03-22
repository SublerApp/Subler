//
//  MovieViewControllerAdditions.swift
//  Subler
//
//  Created by Damiano Galassi on 22/03/2018.
//

import Cocoa

extension SBMovieViewController {

    @IBAction func applySet(_ sender: NSMenuItem) {
        let index = sender.tag
        let preset = PresetManager.shared.metadataPresets[index]

        let dataTypes: UInt = MP42MetadataItemDataType.string.rawValue | MP42MetadataItemDataType.stringArray.rawValue |
                              MP42MetadataItemDataType.bool.rawValue | MP42MetadataItemDataType.integer.rawValue |
                              MP42MetadataItemDataType.integerArray.rawValue | MP42MetadataItemDataType.date.rawValue

        let items = preset.metadata.metadataItemsFiltered(by: MP42MetadataItemDataType(rawValue: dataTypes))

        if preset.replaceAnnotations {
            remove(metadata.metadataItemsFiltered(by: MP42MetadataItemDataType(rawValue: dataTypes)))
        }

        if items.isEmpty == false {
            let identifiers = items.map { $0.identifier }
            remove(metadata.metadataItemsFiltered(byIdentifiers: identifiers))
            add(items)
        }

        let artworkItems = preset.metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyCoverArt)

        if preset.replaceArtworks {
            removeMetadataCoverArtItems(metadata.metadataItemsFiltered(byIdentifier: MP42MetadataKeyCoverArt))
        }

        if artworkItems.isEmpty == false {
            addMetadataCoverArtItems(artworkItems)
        }
    }

    @IBAction func showSaveSet(_ sender: Any) {
        view.window?.beginCriticalSheet(saveSetWindow, completionHandler: nil)
    }

    @IBAction func closeSaveSheet(_ sender: Any) {
        view.window?.endSheet(saveSetWindow)
    }

    @IBAction func saveSet(_ sender: Any) {
        guard let title = saveSetName?.stringValue else { return }

        let preset = MetadataPreset(title: title, metadata: metadata,
                                    replaceArtworks: keepArtworks?.state == .off,
                                    replaceAnnotations: keepAnnotations?.state == .off)

        do {
            try PresetManager.shared.append(newElement: preset)
            view.window?.endSheet(saveSetWindow)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

