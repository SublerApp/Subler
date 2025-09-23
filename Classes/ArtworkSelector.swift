//
//  ArtworkSelector.swift
//  Subler
//
//  Created by Damiano Galassi on 04/08/2017.
//

import Cocoa
import MP42Foundation

private protocol ArtworkImageObjectDelegate: AnyObject {
    func reloadItem(_ item: ArtworkImageObject)
}

private class ArtworkImageObject : Equatable {

    static func == (lhs: ArtworkImageObject, rhs: ArtworkImageObject) -> Bool {
        return lhs.source.url == rhs.source.url
    }

    private var data: Data?
    private var version: Int
    private var cancelled: Bool
    fileprivate let source: Artwork
    private let queue: DispatchQueue
    private weak var delegate: ArtworkImageObjectDelegate?

    init(artwork: Artwork, delegate: ArtworkImageObjectDelegate) {
        self.source = artwork
        self.delegate = delegate
        self.version = 0
        self.cancelled = false
        self.queue = DispatchQueue(label: "artworkQueue")
    }

    func cancel() {
        queue.sync {
            cancelled = true
            delegate = nil
        }
    }

    var image: NSImage? {
        if let data = imageRepresentation() {
            return NSImage(data: data)
        } else {
            return nil
        }
    }

    private func imageRepresentation() -> Data? {
        // Get the data outside the main thread
        var startDownload: Bool = false
        queue.sync {
            if self.version == 0 {
                self.version = 1
                startDownload = true
            }
        }

        if startDownload {
            DispatchQueue.global(qos: .userInitiated).async {
                let localData = URLSession.data(from: self.source.thumbURL)
                var localCancelled = false

                self.queue.sync {
                    self.data = localData
                    self.version = 2
                    localCancelled = self.cancelled
                }

                // We got the data, tell the controller to update the view
                if localCancelled == false {
                    DispatchQueue.main.async {
                        self.delegate?.reloadItem(self)
                    }
                }
            }
        }

        var localData: Data? = nil

        queue.sync {
            if let returnData = data {
                localData = returnData
            }
        }
        return localData
    }

    var imageTitle: String {
        return source.service
    }

    var imageSubtitle: String {
        return source.type.description
    }

}

protocol ArtworkSelectorControllerDelegate: AnyObject {
    func didAddArtworks(metadata: MetadataResult)
}

class ArtworkCollectionView : NSCollectionView {
    override func keyDown(with event: NSEvent) {
        guard let key = event.charactersIgnoringModifiers?.utf16.first else { super.keyDown(with: event); return }

        if key == NSEnterCharacter || key == NSCarriageReturnCharacter {
            nextResponder?.keyDown(with: event)
        } else if selectionIndexPaths.isEmpty {
            if key == NSRightArrowFunctionKey || key == NSDownArrowFunctionKey {
                let indexPathSet = Set([IndexPath(item: 0, section: 0)])
                animator().selectItems(at: indexPathSet, scrollPosition: .bottom)
                delegate?.collectionView?(self, didSelectItemsAt: indexPathSet)
            } else if key == NSLeftArrowFunctionKey || key == NSUpArrowFunctionKey  {
                let numberOfItems = dataSource?.collectionView(self, numberOfItemsInSection: 0) ?? 1
                let indexPathSet = Set([IndexPath(item: numberOfItems - 1, section: 0)])
                animator().selectItems(at: indexPathSet, scrollPosition: .bottom)
                delegate?.collectionView?(self, didSelectItemsAt: indexPathSet)
            } else {
                super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }
}

final class ArtworkSelectorController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, ArtworkImageObjectDelegate {

    @IBOutlet var imageBrowser: NSCollectionView!
    @IBOutlet var slider: NSSlider!
    @IBOutlet var addArtworkButton: NSButton!
    @IBOutlet var loadMoreArtworkButton: NSButton!

    @IBOutlet var progress: NSProgressIndicator!
    @IBOutlet var progressText: NSTextField!

    private var artworksUnloaded: [Artwork]
    private var artworks: [ArtworkImageObject]
    private let standardSize = NSSize(width: 154, height: 192)
    private let metadata: MetadataResult

    private weak var delegate: ArtworkSelectorControllerDelegate?

    // MARK: UI State
    private enum ArtworkSearchState {
        case none
        case downloading
        case closing
    }

    private var state: ArtworkSearchState = .none

    // MARK: - Init
    init(metadata: MetadataResult, delegate: ArtworkSelectorControllerDelegate) {
        self.delegate = delegate
        self.artworksUnloaded = metadata.remoteArtworks
        self.artworks = []
        self.metadata = metadata
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        imageBrowser.delegate = nil
        imageBrowser.dataSource = nil

        for artwork in artworks {
            artwork.cancel()
        }
    }

    override public var nibName: NSNib.Name? {
        return "ArtworkSelector"
    }

    // MARK: - Load images
    override public func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true

        imageBrowser.register(ArtworkSelectorViewItem.self, forItemWithIdentifier: ArtworkSelectorController.itemView)
        loadMoreArtworks(count: 8)

        let type = metadata.mediaKind.description

        if let defaultService = UserDefaults.standard.string(forKey: "SBArtworkSelectorDefaultService|\(type.description)"),
            let defaultType = ArtworkType(rawValue: UserDefaults.standard.integer(forKey: "SBArtworkSelectorDefaultType|\(type.description)")),
            let defaultSize = ArtworkSize(rawValue: UserDefaults.standard.integer(forKey: "SBArtworkSelectorDefaultSize|\(type.description)")){
            selectArtwork(type: defaultType, size: defaultSize, service: defaultService)
        }

        if imageBrowser.selectionIndexPaths.count == 0 {
            selectArtwork(at: 0)
        }

        updateUI()
    }

    override func viewWillAppear() {
        let zoomValue = Prefs.artworkSelectorZoomLevel
        setZoomValue(zoomValue)
        slider.floatValue = zoomValue
    }

    @IBAction func loadMoreArtwork(_ sender: Any) {
        loadMoreArtworks(count: 8)
    }

    // MARK: - User Interface

    private func setZoomValue(_ newZoomValue: Float) {
        if let layout = imageBrowser.collectionViewLayout as? NSCollectionViewFlowLayout {
            if newZoomValue == 50 {
                layout.itemSize = standardSize
            } else if newZoomValue < 50 {
                let zoomValue = (CGFloat(newZoomValue) + 50) / 100
                layout.itemSize = NSSize(width: Int(standardSize.width * zoomValue),
                                         height: Int((standardSize.height - 32) * zoomValue + 32))

            } else {
                let zoomValue = pow((CGFloat(newZoomValue) + 50) / 100, 2.4)
                layout.itemSize = NSSize(width: Int(standardSize.width * zoomValue),
                                         height: Int((standardSize.height - 32) * zoomValue + 32))
            }
        }
    }

    @IBAction func zoomSliderDidChange(_ sender: Any) {
        setZoomValue(slider.floatValue)
        Prefs.artworkSelectorZoomLevel = slider.floatValue
    }

    fileprivate func reloadItem(_ item: ArtworkImageObject) {
        let selectionIndexPaths = imageBrowser.selectionIndexPaths

        if let index = artworks.firstIndex(of: item) {
            let indexPath = IndexPath(item: index, section: 0)
            imageBrowser.reloadItems(at: [indexPath])
        }

            imageBrowser.selectionIndexPaths = selectionIndexPaths
    }

    private func selectArtwork(at index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        imageBrowser.selectItems(at: [indexPath], scrollPosition: .top)
        addArtworkButton.isEnabled = imageBrowser.selectionIndexPaths.isEmpty == false
    }

    private func loadMoreArtworks(count: Int) {
        let endIndex = artworksUnloaded.count < count ? artworksUnloaded.count : count
        let newArtworks = artworksUnloaded[0 ..< endIndex]

        artworks.append(contentsOf: newArtworks.map {  ArtworkImageObject(artwork: $0, delegate: self) })
        artworksUnloaded.removeFirst(endIndex)
        loadMoreArtworkButton.isEnabled = artworksUnloaded.isEmpty == false

        let range = (artworks.count - endIndex ..< artworks.count)
        let indexes = range.map { IndexPath(item: $0, section: 0)}

        imageBrowser.insertItems(at: Set(indexes))
    }

    private func selectArtwork(type: ArtworkType, size: ArtworkSize, service: String) {
        if let artwork = (artworks.filter { $0.source.type == type && $0.source.size == size && $0.source.service == service } as [ArtworkImageObject]).first,
            let index = artworks.firstIndex(of: artwork) {
            selectArtwork(at: index)
        }
        else if let artwork = (artworks.filter { $0.source.type == type && $0.source.size == size } as [ArtworkImageObject]).first,
            let index = artworks.firstIndex(of: artwork) {
            selectArtwork(at: index)
        }
        else if let artwork = (artworks.filter { $0.source.type == type } as [ArtworkImageObject]).first,
            let index = artworks.firstIndex(of: artwork) {
            selectArtwork(at: index)
        }
        else if artworksUnloaded.isEmpty == false {
            for (index, artwork) in artworksUnloaded.enumerated() {
                if artwork.type == type {
                    let offset = artworks.count
                    loadMoreArtworks(count: index + 1)
                    selectArtwork(at: index + offset)
                    break
                }
            }
        }
    }

    private func selectedArtworks() -> [ArtworkImageObject] {
        return imageBrowser.selectionIndexPaths.map { artworks[$0.item] }
    }

    // MARK - UI state

    private func disableUI() {
        [slider, addArtworkButton, loadMoreArtworkButton].forEach { $0.isEnabled = false }
        imageBrowser.isSelectable = false
    }

    private func startProgressReport() {
        progress.startAnimation(self)
        progress.isHidden = false
        switch state {
        case .downloading:
            progressText.stringValue = NSLocalizedString("Downloading artworks…", comment: "")
        case .closing: break
        default: break
        }
        progressText.isHidden = false
    }

    private func stopProgressReport() {
        progress.stopAnimation(self)
        progress.isHidden = true
        progressText.isHidden = true
    }

    private func updateUI() {
        switch state {
        case .none:
            stopProgressReport()
        case .downloading:
            disableUI()
            startProgressReport()
            loadMoreArtworkButton.isHidden = true
        case .closing:
            disableUI()
            loadMoreArtworkButton.isHidden = true
            stopProgressReport()
        }
    }

    // MARK: - Finishing Up

    private func load(artworks: [Artwork]) {
        switch state {
        case .none:

            state = .downloading
            updateUI()

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let downloadedArtworks = artworks.compactMap { (artwork) -> MP42Image? in
                    if let data = URLSession.data(from: artwork.url) {
                        return MP42Image(data: data, type: MP42_ART_JPEG)
                    } else if artwork.service == iTunesStore().name, // Hack, download smaller iTunes version if big iTunes version is not available
                        let data = URLSession.data(from: artwork.url.deletingPathExtension().appendingPathExtension("600x600bb.jpg")) {
                        return MP42Image(data: data, type: MP42_ART_JPEG)
                    } else {
                        return nil
                    }
                }
                DispatchQueue.main.async {
                    self?.loadDone(images: downloadedArtworks)
                }
            }
        default:
            break
        }
    }

    private func loadDone(images: [MP42Image]) {
        self.state = .closing
        self.metadata.artworks.append(contentsOf: images)
        self.delegate?.didAddArtworks(metadata: self.metadata)
        self.updateUI()
    }

    @IBAction func addArtwork(_ sender: Any) {
        load(artworks: selectedArtworks().map { $0.source })
    }

    @IBAction func addNoArtwork(_ sender: Any) {
        delegate?.didAddArtworks(metadata: metadata)
    }

    // MARK: - Data source

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return artworks.count
    }

    static let itemView = NSUserInterfaceItemIdentifier(rawValue: "ArtworkSelectorViewItem")

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ArtworkSelectorController.itemView, for: indexPath)
        guard let collectionViewItem = item as? ArtworkSelectorViewItem, let index = indexPath.last else { return item }

        let artwork = artworks[index]

        collectionViewItem.title = artwork.imageTitle
        collectionViewItem.subtitle = artwork.imageSubtitle
        collectionViewItem.image = artwork.image

        collectionViewItem.doubleAction = #selector(addArtwork)
        collectionViewItem.target = self

        return collectionViewItem
    }

    // MARK: - Delegate

    private func updateSelection() {
        addArtworkButton.isEnabled = imageBrowser.selectionIndexes.isEmpty == false
        if let artwork = selectedArtworks().first {
            let type = metadata.mediaKind.description
            UserDefaults.standard.set(artwork.source.size.rawValue, forKey: "SBArtworkSelectorDefaultSize|\(type.description)")
            UserDefaults.standard.set(artwork.source.type.rawValue, forKey: "SBArtworkSelectorDefaultType|\(type.description)")
            UserDefaults.standard.set(artwork.source.service, forKey: "SBArtworkSelectorDefaultService|\(type.description)")
        }
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }
}
