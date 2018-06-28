//
//  ArtworkSelector.swift
//  Subler
//
//  Created by Damiano Galassi on 04/08/2017.
//

import Cocoa
import Quartz

private protocol ArtworkImageObjectDelegate: AnyObject {
    func reloadItem(_ item: ArtworkImageObject)
}

private class ArtworkImageObject : NSObject {

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

    func image() -> NSImage? {
        if let data = imageRepresentation() as? Data {
            return NSImage(data: data)
        } else {
            return nil
        }
    }

    override func imageRepresentation() -> Any! {
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

        var localData: NSData? = nil

        queue.sync {
            if let returnData = data {
                localData =  NSData(data: returnData)
            }
        }
        return localData
    }

    override func imageRepresentationType() -> String {
        return IKImageBrowserNSDataRepresentationType
    }

    override func imageUID() -> String {
        return source.thumbURL.absoluteString
    }

    override func imageVersion()-> Int {
        var returnValue: Int = 0
        queue.sync {
            returnValue = self.version
        }
        return returnValue
    }

    override func imageTitle() -> String {
        return source.service
    }

    override func imageSubtitle() -> String {
        return source.type.description
    }

}

protocol ArtworkSelectorControllerDelegate: AnyObject {
    func didSelect(artworks: [Artwork])
}

class ArtworkSelectorControllerOldStyle: NSWindowController, ArtworkImageObjectDelegate {

    @IBOutlet var imageBrowser: IKImageBrowserView!
    @IBOutlet var slider: NSSlider!
    @IBOutlet var addArtworkButton: NSButton!
    @IBOutlet var loadMoreArtworkButton: NSButton!

    private var artworksUnloaded: [Artwork]
    private var artworks: [ArtworkImageObject]
    private let initialSize: CGSize?
    private let type: MetadataType

    private weak var delegate: ArtworkSelectorControllerDelegate?

    // MARK: - Init
    init(artworks: [Artwork], size: CGSize? = nil, type: MetadataType, delegate: ArtworkSelectorControllerDelegate) {
        self.delegate = delegate
        self.initialSize = size
        self.artworksUnloaded = artworks
        self.artworks = Array()
        self.type = type
        super.init(window: nil)
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

    override public var windowNibName: NSNib.Name? {
        return "ArtworkSelectorOld"
    }

    // MARK: - Load images
    override public func windowDidLoad() {
        super.windowDidLoad()

        if let size = initialSize { window?.setContentSize(size) }

        loadMoreArtworks(count: 8)

        if let defaultService = UserDefaults.standard.string(forKey: "SBArtworkSelectorDefaultService|\(type.description)"),
            let defaultType = ArtworkType(rawValue: UserDefaults.standard.integer(forKey: "SBArtworkSelectorDefaultType|\(type.description)")) {
            selectArtwork(type: defaultType, service: defaultService)
        }

        if imageBrowser.selectionIndexes().count == 0 {
            imageBrowser.setSelectionIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    @IBAction func loadMoreArtwork(_ sender: Any) {
        loadMoreArtworks(count: 8)
    }

    // MARK: - User Interface
    @IBAction func zoomSliderDidChange(_ sender: Any) {
        imageBrowser.setZoomValue(slider.floatValue)
        imageBrowser.needsDisplay = true
    }

    fileprivate func reloadItem(_ item: ArtworkImageObject) {
        imageBrowser.reloadData()
    }

    private func selectArtwork(at index: Int) {
        imageBrowser.setSelectionIndexes(IndexSet(integer: index), byExtendingSelection: false)
        imageBrowser.scrollIndexToVisible(index)
    }

    private func loadMoreArtworks(count: Int) {
        let endIndex = artworksUnloaded.count < count ? artworksUnloaded.count : count
        artworks.append(contentsOf: artworksUnloaded[0 ..< endIndex].map {  ArtworkImageObject(artwork: $0, delegate: self) })
        artworksUnloaded.removeFirst(endIndex)
        loadMoreArtworkButton.isEnabled = artworksUnloaded.isEmpty == false
        imageBrowser.reloadData()
    }

    private func selectArtwork(type: ArtworkType, service: String) {
        if let artwork = (artworks.filter { $0.source.type == type && $0.source.service == service } as [ArtworkImageObject]).first,
            let index = artworks.index(of: artwork) {
            selectArtwork(at: index)
        }
        else if let artwork = (artworks.filter { $0.source.type == type } as [ArtworkImageObject]).first,
            let index = artworks.index(of: artwork) {
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
        return imageBrowser.selectionIndexes().map { artworks[$0] }
    }

    // MARK: - Finishing Up
    @IBAction func addArtwork(_ sender: Any) {
        delegate?.didSelect(artworks:selectedArtworks().map { $0.source })
    }

    @IBAction func addNoArtwork(_ sender: Any) {
        delegate?.didSelect(artworks: [])
    }

    // MARK: - IKImageBrowserDataSource
    override public func numberOfItems(inImageBrowser aBrowser: IKImageBrowserView!) -> Int {
        return artworks.count
    }

    override public func imageBrowser(_ aBrowser: IKImageBrowserView!, itemAt index: Int) -> Any! {
        return artworks[index]
    }

    // MARK: - IKImageBrowserDelegate
    override public func imageBrowser(_ aBrowser: IKImageBrowserView!, cellWasDoubleClickedAt index: Int) {
        addArtwork(self)
    }

    override public func imageBrowserSelectionDidChange(_ aBrowser: IKImageBrowserView!) {
        addArtworkButton.isEnabled = aBrowser.selectionIndexes().isEmpty == false
        if let artwork = selectedArtworks().first {
            UserDefaults.standard.set(artwork.source.type.rawValue, forKey: "SBArtworkSelectorDefaultType|\(type.description)")
            UserDefaults.standard.set(artwork.source.service, forKey: "SBArtworkSelectorDefaultService|\(type.description)")
        }
    }

}

@available(OSX 10.11, *)
class CollectionView : NSCollectionView {
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


@available(OSX 10.11, *)
class ArtworkSelectorController: NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate, ArtworkImageObjectDelegate {

    @IBOutlet var imageBrowser: NSCollectionView!
    @IBOutlet var slider: NSSlider!
    @IBOutlet var addArtworkButton: NSButton!
    @IBOutlet var loadMoreArtworkButton: NSButton!

    private var artworksUnloaded: [Artwork]
    private var artworks: [ArtworkImageObject]
    private let initialSize: CGSize?
    private let type: MetadataType

    private weak var delegate: ArtworkSelectorControllerDelegate?

    // MARK: - Init
    init(artworks: [Artwork], size: CGSize? = nil, type: MetadataType, delegate: ArtworkSelectorControllerDelegate) {
        self.delegate = delegate
        self.initialSize = size
        self.artworksUnloaded = artworks
        self.artworks = Array()
        self.type = type
        super.init(window: nil)
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

    override public var windowNibName: NSNib.Name? {
        return "ArtworkSelector"
    }

    // MARK: - Load images
    override public func windowDidLoad() {
        super.windowDidLoad()

        window?.contentView?.wantsLayer = true

        if let size = initialSize { window?.setContentSize(size) }

        imageBrowser.register(ArtworkSelectorViewItem.self, forItemWithIdentifier: ArtworkSelectorController.itemView)
        loadMoreArtworks(count: 8)

        if let defaultService = UserDefaults.standard.string(forKey: "SBArtworkSelectorDefaultService|\(type.description)"),
            let defaultType = ArtworkType(rawValue: UserDefaults.standard.integer(forKey: "SBArtworkSelectorDefaultType|\(type.description)")) {
            selectArtwork(type: defaultType, service: defaultService)
        }

        if imageBrowser.selectionIndexPaths.count == 0 {
            let indexPath = IndexPath(item: 0, section: 0)
            imageBrowser.selectItems(at: [indexPath], scrollPosition: .top)
        }
    }

    @IBAction func loadMoreArtwork(_ sender: Any) {
        loadMoreArtworks(count: 8)
    }

    // MARK: - User Interface

    @IBAction func zoomSliderDidChange(_ sender: Any) {
        let standardSize = NSSize(width: 154, height: 194)
        if let layout = imageBrowser.collectionViewLayout as? NSCollectionViewFlowLayout {
            if slider.floatValue == 50 {
                layout.itemSize = standardSize
            } else if slider.floatValue < 50 {
                let zoomValue = (CGFloat(slider.floatValue) + 50) / 100
                layout.itemSize = NSSize(width: Int(standardSize.width * zoomValue),
                                         height: Int(standardSize.height * zoomValue))

            } else {
                let zoomValue = pow((CGFloat(slider.floatValue) + 50) / 100, 2.4)
                layout.itemSize = NSSize(width: Int(standardSize.width * zoomValue),
                                         height: Int(standardSize.height * zoomValue))
            }
        }
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
        let indexPath = IndexPath(item: 0, section: 0)
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

    private func selectArtwork(type: ArtworkType, service: String) {
        if let artwork = (artworks.filter { $0.source.type == type && $0.source.service == service } as [ArtworkImageObject]).first,
            let index = artworks.index(of: artwork) {
            selectArtwork(at: index)
        }
        else if let artwork = (artworks.filter { $0.source.type == type } as [ArtworkImageObject]).first,
            let index = artworks.index(of: artwork) {
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
        return imageBrowser.selectionIndexes.map { artworks[$0] }
    }

    // MARK: - Finishing Up
    @IBAction func addArtwork(_ sender: Any) {
        delegate?.didSelect(artworks:selectedArtworks().map { $0.source })
    }

    @IBAction func addNoArtwork(_ sender: Any) {
        delegate?.didSelect(artworks: [])
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

        collectionViewItem.title = artwork.imageTitle()
        collectionViewItem.subtitle = artwork.imageSubtitle()
        collectionViewItem.image = artwork.image()

        collectionViewItem.doubleAction = #selector(addArtwork)
        collectionViewItem.target = self

        return collectionViewItem
    }

    // MARK: - Delegate

    private func updateSelection() {
        addArtworkButton.isEnabled = imageBrowser.selectionIndexes.isEmpty == false
        if let artwork = selectedArtworks().first {
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
