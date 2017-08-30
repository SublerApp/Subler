//
//  PrefsWindowController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/08/2017.
//

import Cocoa

@objc(SBPrefsWindowController) class PrefsWindowController: NSWindowController {

    @objc public class func registerUserDefaults() {
        let defaults = UserDefaults.standard
        let movieDefaultMap = NSKeyedArchiver.archivedData(withRootObject: MetadataResultMap.movieDefaultMap)
        let tvShowDefaultMap = NSKeyedArchiver.archivedData(withRootObject: MetadataResultMap.tvShowDefaultMap)

        // Migrate 1.2.9 DTS setting
        if defaults.object(forKey: "SBAudioKeepDts") != nil {
            if defaults.bool(forKey: "SBAudioKeepDts") {
                defaults.set(2, forKey: "SBAudioDtsOptions")
            }
            defaults.removeObject(forKey: "SBAudioKeepDts")
        }

        let settings: [String: Any] = ["SBSaveFormat":                  "m4v",
                                       "defaultSaveFormat":             "0",
                                       "SBOrganizeAlternateGroups":     true,
                                       "SBAudioMixdown":                "1",
                                       "SBAudioBitrate":                "96",
                                       "SBAudioConvertAC3":             true,
                                       "SBAudioKeepAC3":                true,
                                       "SBAudioConvertDts":             true,
                                       "SBAudioDtsOptions":             0,
                                       "SBSubtitleConvertBitmap":       true,
                                       "SBRatingsCountry":              "All countries",
                                       "mp464bitOffset":                false,
                                       "chaptersPreviewTrack":          true,
                                       "SBChaptersPreviewPosition":     0.5,

                                       "SBMetadataPreference|Movie":                       "TheMovieDB",
                                       "SBMetadataPreference|Movie|iTunes Store|Language": "USA (English)",
                                       "SBMetadataPreference|Movie|TheMovieDB|Language":   "en",

                                       "SBMetadataPreference|TV":                       "TheTVDB",
                                       "SBMetadataPreference|TV|iTunes Store|Language": "USA (English)",
                                       "SBMetadataPreference|TV|TheTVDB|Language":      "en",
                                       "SBMetadataPreference|TV|TheMovieDB|Language":   "en",

                                       "SBMetadataMovieResultMap":       movieDefaultMap,
                                       "SBMetadataTvShowResultMap":      tvShowDefaultMap,
                                       "SBMetadataKeepEmptyAnnotations": false]

        defaults.register(defaults: settings)
    }

    @IBOutlet var generalView: NSView!
    @IBOutlet var advancedView: NSView!

    let metadataController: MetadataPrefsViewController
    let presetController: PresetPrefsViewController

    let general: NSToolbarItem.Identifier
    let metadata: NSToolbarItem.Identifier
    let presets: NSToolbarItem.Identifier
    let advanced: NSToolbarItem.Identifier

    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "Prefs")
    }

    init() {
        self.metadataController = MetadataPrefsViewController()
        self.presetController = PresetPrefsViewController()

        self.general = NSToolbarItem.Identifier("TOOLBAR_GENERAL")
        self.metadata = NSToolbarItem.Identifier("TOOLBAR_METADATA")
        self.presets = NSToolbarItem.Identifier("TOOLBAR_SETS")
        self.advanced = NSToolbarItem.Identifier("TOOLBAR_ADVANCED")

        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        window?.toolbar?.allowsUserCustomization = false
        window?.toolbar?.selectedItemIdentifier = general

        if let items = window?.toolbar?.items, let item = (items.filter { $0.itemIdentifier == general }).first {
            selectItem(item, animate: false)
        }
    }

    // MARK: Panel switching

    private func view(for identifier: NSToolbarItem.Identifier) -> NSView? {
        if identifier == general { return generalView }
        if identifier == metadata { return metadataController.view }
        if identifier == presets { return presetController.view }
        if identifier == advanced { return advancedView }
        return nil
    }

    private func animationDuration(view: NSView, previousView: NSView?) -> TimeInterval {
        guard let previousView = previousView else { return 0 }
        return TimeInterval(abs(previousView.frame.size.height - view.frame.height)) * 0.0011
    }

    private func selectItem(_ item: NSToolbarItem, animate: Bool) {
        guard let window = self.window,
            let view = self.view(for: item.itemIdentifier),
            window.contentView != view
            else { return }

        let duration = animationDuration(view: view, previousView: window.contentView)
        window.contentView = view

        if window.isVisible && animate {
            NSAnimationContext.runAnimationGroup({ context in
                if #available(OSX 10.11, *) {
                    context.allowsImplicitAnimation = true
                    context.duration = duration
                }
                else {
                    context.duration = 0
                }
                window.layoutIfNeeded()
                view.isHidden = true
            }, completionHandler: {
                view.isHidden = false
                window.title = item.label
            })
        }
        else {
            window.title = item.label
        }
    }

    @IBAction func setPrefView(_ sender: NSToolbarItem) {
        selectItem(sender, animate: true)
    }

    // MARK: General panel

    @IBAction func clearRecentSearches(_ sender: Any) {
        MetadataSearchController.clearRecentSearches()
    }

    @IBAction func deleteCachedMetadata(_ sender: Any) {
        MetadataSearchController.deleteCachedMetadata()
    }

    @IBAction func updateRatingsCountry(_ sender: Any) {
        MP42Ratings.defaultManager.updateCountry()
    }

    @objc dynamic var ratingsCountries: [String] { return MP42Ratings.defaultManager.ratingsCountries }

}
