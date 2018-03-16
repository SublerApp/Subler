//
//  OptionsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 16/03/2018.
//

import Cocoa

@objc(SBOptionsViewController) class OptionsViewController: NSViewController {

    @IBOutlet var destButton: NSPopUpButton!

    private static var observerContext = 0

    @objc private dynamic let options: NSMutableDictionary

    @objc private dynamic var sets: [MetadataPreset]
    private var presetsObserver: Any?

    @objc private dynamic let moviesProviders: [String]
    @objc private dynamic let tvShowsProviders: [String]

    private let moviesProvidersKeyPath: String
    private let tvShowsProvidersKeyPath: String

    @objc private dynamic var movieLanguages: [String]
    @objc private dynamic var tvShowLanguages: [String]

    @objc private dynamic let languages: [String]
    private let langManager: MP42Languages

    private var recentDestinations: [URL]

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "QueueOptions")
    }

    @objc init(options: NSMutableDictionary) {
        self.options = options

        self.sets = []

        self.moviesProviders = MetadataSearch.movieProviders
        self.tvShowsProviders = MetadataSearch.tvProviders
        self.moviesProvidersKeyPath = "options.SBQueueMovieProvider"
        self.tvShowsProvidersKeyPath = "options.SBQueueTVShowProvider"
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

    deinit {
        removeObserver(self, forKeyPath: moviesProvidersKeyPath, context: &OptionsViewController.observerContext)
        removeObserver(self, forKeyPath: tvShowsProvidersKeyPath, context: &OptionsViewController.observerContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Hack to fix crappy anti-aliasing on Yosemite
        // unfortunately it fixes the checkboxes anti-aliasing,
        // but break the popup buttons one…
        view.wantsLayer = true

        for subview in view.subviews {
            if let button = subview as? NSButton {
                button.attributedTitle = NSAttributedString(string: button.title,
                                                            attributes: [NSAttributedStringKey.foregroundColor: NSColor.labelColor,
                                                                        NSAttributedStringKey.font: NSFont.labelFont(ofSize: 11)])

            }
        }

        // Observe the providers changes
        // to update the specific provider languages popup
        addObserver(self, forKeyPath: moviesProvidersKeyPath, options: [.initial, .new], context: &OptionsViewController.observerContext)
        addObserver(self, forKeyPath: tvShowsProvidersKeyPath, options: [.initial, .new], context: &OptionsViewController.observerContext)

        prepareDestinationPopUp()
        preparePresetsPopUp()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &OptionsViewController.observerContext, let changeDict = change else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        if keyPath == moviesProvidersKeyPath {
            let newProvider = changeDict[.newKey] as? String ?? MetadataSearch.movieProviders.first
            let oldLanguage = options[SBQueueMovieProviderLanguage] as? String ?? "und"
            let service = MetadataSearch.service(name: newProvider)

            movieLanguages = localizedLanguages(service: service)

            if service.languages.contains(oldLanguage) == false {
                options[SBQueueMovieProviderLanguage] = service.defaultLanguage
            }
        } else if keyPath == tvShowsProvidersKeyPath {
            let newProvider = changeDict[.newKey] as? String ?? MetadataSearch.tvProviders.first
            let oldLanguage = options[SBQueueTVShowProviderLanguage] as? String ?? "und"
            let service = MetadataSearch.service(name: newProvider)

            tvShowLanguages = localizedLanguages(service: service)

            if service.languages.contains(oldLanguage) == false {
                options[SBQueueTVShowProviderLanguage] = service.defaultLanguage
            }
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
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
        if let url = self.options[SBQueueDestination] as? URL, let item = (destButton.menu?.items.filter { $0.representedObject as? URL == url })?.first {
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
            recentDestinations = loadedDestinations.compactMap { URL(fileURLWithPath: $0) }
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

        if let currentURL = self.options[SBQueueDestination] as? URL, recentDestinations.contains(currentURL) == false {
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
                self.options[SBQueueDestination] = url
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
            options[SBQueueDestination] = url
        } else {
            options[SBQueueDestination] = nil
        }
    }

    // MARK: Presets popUp

    private func preparePresetsPopUp() {
        let update: (Notification) -> Void = { [weak self] notification in
            guard let s = self else { return }
            s.sets = PresetManager.shared.metadataPresets
            if let set = s.options[SBQueueSet] as? MetadataPreset, s.sets.contains(set) == false {
                s.options[SBQueueSet] = nil
            }
        }

        update(Notification(name: Notification.Name(rawValue: "")))

        presetsObserver = NotificationCenter.default.addObserver(forName: PresetManager.shared.updateNotification,
                                                          object: nil,
                                                          queue: OperationQueue.main,
                                                          using: update)
    }

}
