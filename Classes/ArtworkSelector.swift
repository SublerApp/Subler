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
    fileprivate let artwork: RemoteImage
    private let queue: DispatchQueue
    private weak var delegate: ArtworkImageObjectDelegate?

    init(artwork: RemoteImage, delegate: ArtworkImageObjectDelegate) {
        self.artwork = artwork
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
                let localData = URLSession.data(from: self.artwork.url)
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
        return artwork.thumbURL.absoluteString
    }

    @objc override func imageVersion()-> Int {
        var returnValue: Int = 0
        queue.sync {
            returnValue = self.version
        }
        return returnValue
    }

    @objc override func imageTitle() -> String {
        return artwork.providerName.components(separatedBy: "|").first ?? ""
    }

    @objc override func imageSubtitle() -> String {
        let components =  artwork.providerName.components(separatedBy: "|")
        return components.count > 1 ? components[1] : ""
    }

}

public protocol ArtworkSelectorControllerDelegate: AnyObject {
    func didSelect(artworks: [RemoteImage])
}

public class ArtworkSelectorController: NSWindowController, ArtworkImageObjectDelegate {

    @IBOutlet var imageBrowser: IKImageBrowserView!
    @IBOutlet var slider: NSSlider!
    @IBOutlet var addArtworkButton: NSButton!
    @IBOutlet var loadMoreArtworkButton: NSButton!

    private var artworksUnloaded: [RemoteImage]
    private var artworks: [ArtworkImageObject]

    private weak var delegate: ArtworkSelectorControllerDelegate?

    // MARK: - Init
    init(artworks: [RemoteImage], delegate: ArtworkSelectorControllerDelegate) {
        self.delegate = delegate
        self.artworksUnloaded = artworks
        self.artworks = Array()
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
        loadMoreArtwork(self)
        imageBrowser.setSelectionIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    @IBAction func loadMoreArtwork(_ sender: Any) {
        let endIndex = artworksUnloaded.count < 10 ? artworksUnloaded.count : 10
        artworks.append(contentsOf: artworksUnloaded[0 ..< endIndex].map {  ArtworkImageObject(artwork: $0, delegate: self) })
        artworksUnloaded.removeFirst(endIndex)
        loadMoreArtworkButton.isEnabled = artworksUnloaded.count > 0
        imageBrowser.reloadData()
    }

    // MARK: - User Interface
    @IBAction func zoomSliderDidChange(_ sender: Any) {
        imageBrowser.setZoomValue(slider.floatValue)
        imageBrowser.needsDisplay = true
    }

    func reloadData() {
        imageBrowser.reloadData()
    }

    // MARK: - Finishing Up
    @IBAction func addArtwork(_ sender: Any) {
        if let indexes = imageBrowser.selectionIndexes() {
            let selectedArtworks = indexes.map { artworks[$0].artwork }
            delegate?.didSelect(artworks: selectedArtworks)
        }
        else {
            delegate?.didSelect(artworks: [])
        }
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
        addArtworkButton.isEnabled = aBrowser.selectionIndexes().count > 0
    }

}
