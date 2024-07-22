//
//  MetadataSearchWindowController.swift
//  Subler
//
//  Created by Damiano Galassi on 06/08/2019.
//

import Cocoa

protocol MetadataSearchViewControllerDelegate : AnyObject {
    func didSelect(metadata: MetadataResult)
}

class MetadataSearchViewController: ViewController, MetadataSearchControllerDelegate, ArtworkSelectorControllerDelegate {

    private let searchTerms: MetadataSearchTerms

    private lazy var metadataViewController: MetadataSearchController = {
        return MetadataSearchController(delegate: self, searchTerms: searchTerms)
    }()
    private var artworkViewController: ArtworkSelectorController?

    private weak var delegate: MetadataSearchViewControllerDelegate?

    init(delegate: MetadataSearchViewControllerDelegate, searchTerms: MetadataSearchTerms = .none) {
        self.delegate = delegate
        self.searchTerms = searchTerms
        super.init(nibName: nil, bundle: nil)
        self.autosave = "MetadataSearchViewControllerAutosaveIdentifier"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        addChild(metadataViewController)
        view.addSubview(metadataViewController.view)
    }

    override func viewDidAppear() {
        self.view.window?.autorecalculatesKeyViewLoop = true
    }

    override func addChild(_ childViewController: NSViewController) {
        childViewController.view.frame.size = view.frame.size
        childViewController.view.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        super.addChild(childViewController)
    }

    override func transition(from fromViewController: NSViewController, to toViewController: NSViewController, options: NSViewController.TransitionOptions = [], completionHandler completion: (() -> Void)? = nil) {
        addChild(toViewController)
        super.transition(from: fromViewController, to: toViewController, options: options, completionHandler: completion)
    }

    func didSelect(metadata: MetadataResult?) {
        if let result = metadata {
            if result.remoteArtworks.isEmpty {
                delegate?.didSelect(metadata: result)
                presentingViewController?.dismiss(self)
            } else {
                let controller = ArtworkSelectorController(metadata: result, delegate: self)
                artworkViewController = controller
                transition(from: metadataViewController, to: controller, options: [.slideForward], completionHandler: {
                    self.removeChild(at: 0)
                    self.view.window?.makeFirstResponder(self.artworkViewController?.imageBrowser)
                })
            }
        } else {
            presentingViewController?.dismiss(self)
        }
    }

    func didAddArtworks(metadata: MetadataResult) {
        delegate?.didSelect(metadata: metadata)
        presentingViewController?.dismiss(self)
    }
}
