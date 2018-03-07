//
//  OutputPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 30/11/2017.
//

import Cocoa

class OutputPrefsViewController: NSViewController {

    @IBOutlet var movieField: NSTokenField!
    @IBOutlet var tvShowField: NSTokenField!

    var moviePopover: NSPopover?
    var tvShowPopover: NSPopover?

    let tokenDelegate: TokenDelegate

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "OutputPrefsViewController")
    }

    init() {
        let separators: CharacterSet = CharacterSet(charactersIn: "{}")
        self.tokenDelegate = TokenDelegate(displayMenu: true, displayString: { localizedMetadataKeyName($0.text.trimmingCharacters(in: separators)) })
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Filename", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        movieField.delegate = tokenDelegate
        tvShowField.delegate = tokenDelegate

        movieField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
        tvShowField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")

        movieField.objectValue = UserDefaults.standard.tokenArray(forKey: "SBMovieFormatTokens")
        tvShowField.objectValue = UserDefaults.standard.tokenArray(forKey: "SBTVShowFormatTokens")
    }

    private func save() {
        UserDefaults.standard.set(movieField.objectValue as! [Token], forKey: "SBMovieFormatTokens")
        UserDefaults.standard.set(tvShowField.objectValue as! [Token], forKey: "SBTVShowFormatTokens")
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

    override func controlTextDidEndEditing(_ obj: Notification) {
        save()
    }

    @IBAction func setTokenCase(_ sender: NSMenuItem) {
        guard let token = sender.representedObject as? Token,
            let tokenCase = Token.Case(rawValue: sender.tag) else { return }

        if token.textCase == tokenCase {
            token.textCase = .none
        } else {
            token.textCase = tokenCase
        }

        save()
    }

    @IBAction func setTokenPadding(_ sender: NSMenuItem) {
        guard let token = sender.representedObject as? Token,
            let tokenPadding = Token.Padding(rawValue: sender.tag) else { return }

        if token.textPadding == tokenPadding {
            token.textPadding = .none
        } else {
            token.textPadding = tokenPadding
        }

        save()
    }

}
