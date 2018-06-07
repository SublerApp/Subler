//
//  TokensViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 01/12/2017.
//

import Cocoa
import MP42Foundation

class TokensViewController: NSViewController, NSTextFieldDelegate {

    @IBOutlet var tokenField: NSTokenField!
    let tokens: [Token]
    let tokenDelegate: TokenDelegate

    override var nibName: NSNib.Name? {
        return "TokensViewController"
    }

    init(tokens: [String]) {
        self.tokens = tokens.map { Token(text: "{\($0)}") }

        let separators: CharacterSet = CharacterSet(charactersIn: "{}")
        self.tokenDelegate = TokenDelegate(displayMenu: false, displayString: { localizedMetadataKeyName($0.text.trimmingCharacters(in: separators)) })

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tokenField.delegate = tokenDelegate
        tokenField.tokenizingCharacterSet = CharacterSet(charactersIn: "/")
        tokenField.objectValue = tokens
    }

}
