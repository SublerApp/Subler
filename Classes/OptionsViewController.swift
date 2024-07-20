//
//  OptionsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 16/03/2018.
//

import Cocoa
import MP42Foundation

final class OptionsViewController: NSViewController, NSUserInterfaceValidations {

    @IBOutlet weak var sendToExternalApp: NSButton!
    @IBOutlet var destButton: NSPopUpButton!

    @objc private dynamic let options: QueuePreferences

    @objc private dynamic var sets: [MetadataPreset]
    private var presetsObserver: Any?

    @objc private dynamic let moviesProviders: [String]
    @objc private dynamic let tvShowsProviders: [String]

    @objc private dynamic var movieLanguages: [String]
    @objc private dynamic var tvShowLanguages: [String]

    private var moviesObserver: Any?
    private var tvShowObserver: Any?

    @objc private dynamic let languages: [String]
    private let langManager: MP42Languages

    private var recentDestinations: [URL]

    override var nibName: NSNib.Name? {
        return "QueueOptions"
    }

    init(options: QueuePreferences) {
        self.options = options

        self.sets = []

        self.moviesProviders = MetadataSearch.movieProviders
        self.tvShowsProviders = MetadataSearch.tvProviders
        self.movieLanguages = []
        self.tvShowLanguages = []

        self.langManager = MP42Languages.defaultManager
        self.languages = self.langManager.localizedExtendedLanguages

        self.recentDestinations = []

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(macOS 10.15, *) {
            sendToExternalApp.title = NSLocalizedString("Send to TV", comment: "Send to tv app menu item")
        }

        // Observe the providers changes
        // to update the specific provider languages popup

        moviesObserver = options.observe(\.movieProvider, options: [.initial, .new]) { [weak self] observed, change in
            guard let s = self else { return }
            let newProvider = change.newValue ?? MetadataSearch.movieProviders.first
            let oldLanguage = s.options.movieProviderLanguage
            let service = MetadataSearch.service(name: newProvider)

            s.movieLanguages = s.localizedLanguages(service: service)

            if service.languages.contains(oldLanguage) == false {
                s.options.movieProviderLanguage = service.defaultLanguage
            }
        }

        tvShowObserver = options.observe(\.tvShowProvider, options: [.initial, .new]) { [weak self] observed, change in
            guard let s = self else { return }
            let newProvider = change.newValue ?? MetadataSearch.tvProviders.first
            let oldLanguage = s.options.tvShowProviderLanguage
            let service = MetadataSearch.service(name: newProvider)

            s.tvShowLanguages = s.localizedLanguages(service: service)

            if service.languages.contains(oldLanguage) == false {
                s.options.tvShowProviderLanguage = service.defaultLanguage
            }
        }

        prepareDestinationPopUp()
        preparePresetsPopUp()
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(chooseDestination(_:)),
             #selector(destination(_:)):
             return true
        default:
            return false
        }
    }

    private func localizedLanguages(service: MetadataService) -> [String] {
        let type = service.languageType
        return service.languages.map { (lang: String) -> String in
            if type == LanguageType.ISO {
                return langManager.localizedLang(forExtendedTag: lang)
            } else {
                return lang
            }
        }
    }

    // MARK: Destination popUp

    private func menuItem(url: URL) -> NSMenuItem {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        let item = NSMenuItem(title: url.lastPathComponent, action: #selector(destination(_:)), keyEquivalent: "")
        item.image = icon
        item.target = self
        item.representedObject = url
        item.toolTip = url.path
        return item
    }

    private func moviesFolderURL() -> URL? {
        let fileManager = FileManager.default
        return fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first
    }

    private func insertDestinationItem(_ item: NSMenuItem) {
        destButton.menu?.insertItem(item, at: 0)
    }

    private func insertAndSelect(_ url: URL) {
        if let item = (destButton.menu?.items.filter { $0.representedObject as? URL == url })?.first {
            destButton.menu?.removeItem(item)
            insertDestinationItem(item)
            destButton.select(item)
        } else {
            let item = menuItem(url: url)
            insertDestinationItem(item)
            destButton.select(item)
        }
    }

    private func selectCurrentDestination() {
        if let url = self.options.destination, let item = (destButton.menu?.items.filter { $0.representedObject as? URL == url })?.first {
            destButton.select(item)
        } else {
            destButton.selectItem(withTag: sameAsFileTag)
        }
    }

    private func saveRecentDestinations() {
        let destinationsPath = recentDestinations.map { $0.path }
        UserDefaults.standard.set(destinationsPath, forKey: "SBQueueRecentDestinations")
        // TODO: Sandbox
    }

    private func loadRecentDestinations() {
        if let loadedDestinations = UserDefaults.standard.array(forKey: "SBQueueRecentDestinations") as? [String] {
            recentDestinations = loadedDestinations.compactMap { URL(fileURLWithPath: $0, isDirectory: true) }
            if recentDestinations.count > 6 {
                recentDestinations = Array(recentDestinations[0..<6])
            }
        }
    }

    private let sameAsFileTag = 10

    private func prepareDestinationPopUp() {
        loadRecentDestinations()

        if let moviesURL = moviesFolderURL(), recentDestinations.contains(moviesURL) == false {
            recentDestinations.append(moviesURL)
        }

        if let currentURL = self.options.destination, recentDestinations.contains(currentURL) == false {
            recentDestinations.insert(currentURL, at: 0)
        }

        for url in recentDestinations {
            let item = menuItem(url: url)
            insertDestinationItem(item)
        }

        selectCurrentDestination()
    }

    @IBAction func chooseDestination(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        panel.begin(completionHandler: { (response) in
            if response == NSApplication.ModalResponse.OK, let url = panel.url {
                self.options.destination = url
                self.insertAndSelect(url)
                self.recentDestinations.insert(url, at: 0)
                self.saveRecentDestinations()
            } else {
                self.selectCurrentDestination()
            }
        })
    }

    @IBAction func destination(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            options.destination = url
        } else {
            options.destination = nil
        }
    }

    // MARK: Presets popUp

    private func preparePresetsPopUp() {
        let update: (Notification) -> Void = { [weak self] notification in
            guard let s = self else { return }
            s.sets = PresetManager.shared.metadataPresets
            if let set = s.options.metadataSet, s.sets.contains(set) == false {
                s.options.metadataSet = nil
            }
        }

        update(Notification(name: Notification.Name(rawValue: "")))

        presetsObserver = NotificationCenter.default.addObserver(forName: PresetManager.updateNotification,
                                                          object: nil,
                                                          queue: OperationQueue.main,
                                                          using: update)
    }

}
