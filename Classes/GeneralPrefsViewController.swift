//
//  GeneralPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 06/02/2018.
//

import Cocoa
import MP42Foundation

class GeneralPrefsViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("General", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var nibName: NSNib.Name? {
        return "GeneralPrefsViewController"
    }

    // MARK: Save As location popUp

    @IBOutlet var saveLocationPopUp: NSPopUpButton!

    private let customLocationTag = 2

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareSaveLocationPopUp()
    }

    private func menuItem(url: URL) -> NSMenuItem {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        let item = NSMenuItem(title: url.lastPathComponent, action: #selector(setSaveLocation(_:)), keyEquivalent: "")
        item.image = icon
        item.target = self
        item.representedObject = url
        item.toolTip = url.path
        item.tag = customLocationTag
        return item
    }

    /// Rebuilds the custom folder item, then selects the current location.
    private func prepareSaveLocationPopUp() {
        guard let menu = saveLocationPopUp.menu else { return }

        if let item = menu.items.first(where: { $0.tag == customLocationTag }) {
            menu.removeItem(item)
        }

        if let url = Prefs.saveAsCustomLocation {
            menu.insertItem(menuItem(url: url), at: 2)
        }

        selectCurrentSaveLocation()
    }

    private func selectCurrentSaveLocation() {
        let location = Prefs.saveAsLocation

        if location == .custom && Prefs.saveAsCustomLocation == nil {
            saveLocationPopUp.selectItem(withTag: SaveAsLocation.lastUsed.rawValue)
        } else {
            saveLocationPopUp.selectItem(withTag: location.rawValue)
        }
    }

    @IBAction func setSaveLocation(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            Prefs.saveAsCustomLocation = url
            Prefs.saveAsLocation = .custom
        } else {
            Prefs.saveAsLocation = SaveAsLocation(rawValue: sender.tag) ?? .lastUsed
        }
    }

    @IBAction func chooseSaveLocation(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Prefs.saveAsCustomLocation = url
                Prefs.saveAsLocation = .custom
            }
            self.prepareSaveLocationPopUp()
        }
    }

    @IBAction func clearRecentSearches(_ sender: Any) {
        MetadataSearchController.clearRecentSearches()
    }

    @IBAction func deleteCachedMetadata(_ sender: Any) {
        MetadataSearchController.deleteCachedMetadata()
    }

    @IBAction func updateRatingsCountry(_ sender: Any) {
        // Unused
    }

    @objc dynamic var ratingsCountries: [String] { return Ratings.shared.countries.map { $0.displayName } }

    @objc dynamic var logFormatOptions: [String] {
        return [
            NSLocalizedString("Time Only", comment: ""),
            NSLocalizedString("Date and Time", comment: "")
        ]
    }
    
}
