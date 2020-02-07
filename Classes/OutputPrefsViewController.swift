//
//  OutputPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 30/11/2017.
//

import Cocoa
import MP42Foundation

class OutputPrefsViewController: NSViewController, TokenChangeObserver {

    @IBOutlet var movieField: NSTokenField!
    @IBOutlet var tvShowField: NSTokenField!

    var moviePopover: NSPopover?
    var tvShowPopover: NSPopover?

    let tokenDelegate: TokenDelegate

    override var nibName: NSNib.Name? {
        return "OutputPrefsViewController"
    }

    init() {
        let separators: CharacterSet = CharacterSet(charactersIn: "{}")
        self.tokenDelegate = TokenDelegate(displayMenu: true,
                                           displayString: { localizedMetadataKeyName($0.text.trimmingCharacters(in: separators)) })
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Filename", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tokenDelegate.delegate = self

        movieField.delegate = tokenDelegate
        tvShowField.delegate = tokenDelegate

        movieField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
        tvShowField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")

        movieField.objectValue = MetadataPrefs.movieFormatTokens
        tvShowField.objectValue = MetadataPrefs.tvShowFormatTokens
    }

    private func save() {
        MetadataPrefs.movieFormatTokens = movieField.objectValue as! [Token]
        MetadataPrefs.tvShowFormatTokens = tvShowField.objectValue as! [Token]
    }

    // MARK: Actions

    @IBAction func showMovieTokens(_ sender: NSView) {
        if let popover = tvShowPopover {
            popover.close()
            tvShowPopover = nil
        }
        if let popover = moviePopover {
            popover.close()
            moviePopover = nil
        }
        else {
            moviePopover = showTokensPopover(tokens: MP42Metadata.writableMetadata, view: sender)
        }
    }

    @IBAction func showTvShowTokens(_ sender: NSView) {
        if let popover = moviePopover {
            popover.close()
            moviePopover = nil
        }
        if let popover = tvShowPopover {
            popover.close()
            tvShowPopover = nil
        }
        else {
            tvShowPopover = showTokensPopover(tokens: MP42Metadata.writableMetadata, view: sender)
        }
    }

    private func showTokensPopover(tokens: [String], view: NSView) -> NSPopover {
        let tokensController = TokensViewController(tokens: tokens)
        let p = NSPopover()
        p.contentViewController = tokensController
        p.show(relativeTo: view.bounds, of: view, preferredEdge: NSRectEdge.maxY)
        return p
    }

    // MARK: Format Token Field Delegate

    func tokenDidChange(_ obj: Notification?) {
        save()
    }

}
