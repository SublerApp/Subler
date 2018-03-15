//
//  PrefsWindowController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/08/2017.
//

import Cocoa

class PrefsWindowController: NSWindowController, NSWindowDelegate {

    public class func registerUserDefaults() {
        let defaults = UserDefaults.standard

        let encoder = JSONEncoder()

        let movieDefaultMap = try? encoder.encode(MetadataResultMap.movieDefaultMap)
        let tvShowDefaultMap = try? encoder.encode(MetadataResultMap.tvShowDefaultMap)

        let movieFormat = try? encoder.encode([Token(text: "{Name}")])
        let tvShowFormat = try? encoder.encode([Token(text: "{TV Show}"), Token(text: " s", isPlaceholder: false), Token(text: "{TV Season}"), Token(text: "e", isPlaceholder: false), Token(text: "{TV Episode #}")])

        if defaults.integer(forKey: "SBUpgradeCheck") < 1 {
            // Migrate 1.2.9 DTS setting
            if defaults.object(forKey: "SBAudioKeepDts") != nil {
                if defaults.bool(forKey: "SBAudioKeepDts") {
                    defaults.set(2, forKey: "SBAudioDtsOptions")
                }
                defaults.removeObject(forKey: "SBAudioKeepDts")
            }

            // Migrate 1.4.8 filename format settings
            let oldMovieFormat = defaults.tokenArrayFromOldStylePrefs(forKey: "SBMovieFormat")
            if oldMovieFormat.isEmpty == false {
                defaults.set(oldMovieFormat, forKey: "SBMovieFormatTokens")
            }

            let oldTvShowFormat = defaults.tokenArrayFromOldStylePrefs(forKey: "SBTVShowFormat")
            if oldTvShowFormat.isEmpty == false {
                defaults.set(oldTvShowFormat, forKey: "SBTVShowFormatTokens")
            }

            // Migrate 1.4.8 metadata map settings
            if let oldStyleMovieResultMap = defaults.mapFromOldStylePrefs(forKey: "SBMetadataMovieResultMap") {
                defaults.set(oldStyleMovieResultMap, forKey: "SBMetadataMovieResultMap2")
            }

            if let oldStyleTvShowResultMap = defaults.mapFromOldStylePrefs(forKey: "SBMetadataTvShowResultMap") {
                defaults.set(oldStyleTvShowResultMap, forKey: "SBMetadataTvShowResultMap2")
            }

            defaults.set(1, forKey: "SBUpgradeCheck")
        }

        let settings: [String: Any] = ["SBSaveFormat":                  "m4v",
                                       "defaultSaveFormat":             "0",
                                       "SBOrganizeAlternateGroups":     true,
                                       "SBInferMediaCharacteristics":   false,
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

                                       "SBMovieFormatTokens":           movieFormat ?? "",
                                       "SBTVShowFormatTokens":          tvShowFormat ?? "",
                                       "SBSetMovieFormat":              false,
                                       "SBSetTVShowFormat":             false,

                                       "SBMetadataPreference|Movie":                       "TheMovieDB",
                                       "SBMetadataPreference|Movie|iTunes Store|Language": "USA (English)",
                                       "SBMetadataPreference|Movie|TheMovieDB|Language":   "en",

                                       "SBMetadataPreference|TV":                       "TheTVDB",
                                       "SBMetadataPreference|TV|iTunes Store|Language": "USA (English)",
                                       "SBMetadataPreference|TV|TheTVDB|Language":      "en",
                                       "SBMetadataPreference|TV|TheMovieDB|Language":   "en",

                                       "SBMetadataMovieResultMap2":       movieDefaultMap ?? "",
                                       "SBMetadataTvShowResultMap2":      tvShowDefaultMap ?? "",
                                       "SBMetadataKeepEmptyAnnotations": false,

                                       "SBFileImporterImportMetadata": true,
                                       
                                       "SBForceHvc1": true]

        defaults.register(defaults: settings)
    }

    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "PrefsWindowController")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        window?.toolbar?.allowsUserCustomization = false
        window?.toolbar?.selectedItemIdentifier = general

        if let items = window?.toolbar?.items, let item = (items.filter { $0.itemIdentifier == general }).first {
            selectItem(item, animate: false)
        }
    }

    func windowWillClose(_ notification: Notification) {
        _ = self.window?.endEditing()
    }

    lazy var generalController: GeneralPrefsViewController = { return GeneralPrefsViewController() }()
    lazy var metadataController: MetadataPrefsViewController = { return MetadataPrefsViewController() }()
    lazy var presetController: PresetPrefsViewController = { return PresetPrefsViewController() }()
    lazy var outputController: OutputPrefsViewController = { return OutputPrefsViewController() }()
    lazy var advancedController: AdvancedPrefsViewController = { return AdvancedPrefsViewController() }()

    let general: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_GENERAL")
    let metadata: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_METADATA")
    let presets: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_SETS")
    let output: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_OUTPUT")
    let advanced: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_ADVANCED")

    // MARK: Panel switching

    private func view(for identifier: NSToolbarItem.Identifier) -> NSView? {
        if identifier == general { return generalController.view }
        if identifier == metadata { return metadataController.view }
        if identifier == presets { return presetController.view }
        if identifier == output { return outputController.view }
        if identifier == advanced { return advancedController.view }
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

}
