//
//  MovieViewControllerAdditions.swift
//  Subler
//
//  Created by Damiano Galassi on 22/03/2018.
//

import Cocoa

extension SBMovieViewController {

    @IBAction func updateSetsMenu(_ sender: Any) {
        guard let menu = setsPopUp?.menu else { return }

        while menu.numberOfItems > 1 {
            menu.removeItem(at: 1)
        }

        let saveSetItem = NSMenuItem(title: NSLocalizedString("Save Set…", comment: "Set menu"), action: #selector(showSaveSet(_:)), keyEquivalent: "")
        saveSetItem.target = self
        menu.addItem(saveSetItem)

        let allSetItem = NSMenuItem(title: NSLocalizedString("All", comment: "Set menu All set"), action: #selector(addMetadataSet(_:)), keyEquivalent: "")
        allSetItem.target = self
        allSetItem.tag = 0
        menu.addItem(allSetItem)

        let movieSetItem = NSMenuItem(title: NSLocalizedString("Movie", comment: "Set menu Movie set"), action: #selector(addMetadataSet(_:)), keyEquivalent: "")
        movieSetItem.target = self
        movieSetItem.tag = 1
        menu.addItem(movieSetItem)

        let tvSetItem = NSMenuItem(title: NSLocalizedString("TV Show", comment: "Set menu TV Show Set"), action: #selector(addMetadataSet(_:)), keyEquivalent: "")
        tvSetItem.target = self
        tvSetItem.tag = 2
        menu.addItem(tvSetItem)

        let presets = PresetManager.shared.metadataPresets

        if presets.isEmpty == false {
            menu.addItem(NSMenuItem.separator())
        }

        for (index, preset) in presets.enumerated() {
            let item = NSMenuItem(title: preset.title, action: #selector(applySet(_:)), keyEquivalent: "")
            if index < 9 {
                item.keyEquivalent = "\(index + 1)"
            }
            item.target = self
            item.tag = index

            menu.addItem(item)
        }
    }

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

