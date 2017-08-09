//
//  ArtworkSelector.swift
//  Subler
//
//  Created by Damiano Galassi on 04/08/2017.
//

import Cocoa
import Quartz

private protocol ArtworkImageObjectDelegate: AnyObject {
    func reloadData()
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

    @objc override func imageRepresentation() -> Any! {
        // Get the data outside the main thread
        var startDownload: Bool = false
        queue.sync {
            if self.version == 0 {
                self.version = 1
                startDownload = true
            }
        }

        if startDownload {
            DispatchQueue.global(priority: .default).async {
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
                        self.delegate?.reloadData()
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

    @objc override func imageRepresentationType() -> String {
        return IKImageBrowserNSDataRepresentationType
    }

    @objc override func imageUID() -> String {
        return source.thumbURL.absoluteString
    }

    @objc override func imageVersion()-> Int {
        var returnValue: Int = 0
        queue.sync {
            returnValue = self.version
        }
        return returnValue
    }

    @objc override func imageTitle() -> String {
        return source.service
    }

    @objc override func imageSubtitle() -> String {
        return source.type
    }

}

public protocol ArtworkSelectorControllerDelegate: AnyObject {
    func didSelect(artworks: [Artwork])
}

public class ArtworkSelectorController: NSWindowController, ArtworkImageObjectDelegate {

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
        return NSNib.Name(rawValue: "ArtworkSelector")
    }

    // MARK: - Load images
    override public func windowDidLoad() {
        super.windowDidLoad()

        if let size = initialSize { window?.setContentSize(size) }

        loadMoreArtworks(count: 8)

        if let defaultType = UserDefaults.standard.string(forKey: "SBArtworkSelectorDefault|\(type.description)") {
            selectArtwork(type: defaultType)
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

    fileprivate func reloadData() {
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

    private func selectArtwork(type: String) {
        if let artwork = (artworks.filter { $0.imageSubtitle() == type } as [ArtworkImageObject]).first,
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
            UserDefaults.standard.set(artwork.source.type, forKey: "SBArtworkSelectorDefault|\(type.description)")
        }
    }

}
