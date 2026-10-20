//
//  PrefsWindowController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/08/2017.
//

import Cocoa

class PrefsWindowController: NSWindowController, NSWindowDelegate {

    override var windowNibName: NSNib.Name? {
        return "PrefsWindowController"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        if #available(macOS 11, *) {
            window?.toolbarStyle = .preference

            for item in window?.toolbar?.items ?? [] {
                switch item.itemIdentifier {
                case general:
                    item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "")
                case metadata:
                    item.image = NSImage(systemSymbolName: "network", accessibilityDescription: "")
                case presets:
                    item.image = NSImage(systemSymbolName: "books.vertical", accessibilityDescription: "")
                case output:
                    item.image = NSImage(systemSymbolName: "rectangle.and.pencil.and.ellipsis", accessibilityDescription: "")
                case ocr:
                    item.image = NSImage(systemSymbolName: "doc.text.viewfinder", accessibilityDescription: "")
                case advanced:
                    item.image = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "")
                default:
                    item.image = NSImage(systemSymbolName: "placeholdertext.fill", accessibilityDescription: "")
                }
            }
        }

        window?.toolbar?.allowsUserCustomization = false
        window?.toolbar?.selectedItemIdentifier = general

        if let items = window?.toolbar?.items, let item = (items.first { $0.itemIdentifier == general }) {
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
    lazy var ocrController: OCRPrefsViewController = { return OCRPrefsViewController() }()
    lazy var advancedController: AdvancedPrefsViewController = { return AdvancedPrefsViewController() }()

    let general: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_GENERAL")
    let metadata: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_METADATA")
    let presets: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_SETS")
    let output: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_OUTPUT")
    let ocr: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_OCR")
    let advanced: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TOOLBAR_ADVANCED")

    // MARK: Panel switching

    private func view(for identifier: NSToolbarItem.Identifier) -> NSView {
        if identifier == general { return generalController.view }
        if identifier == metadata { return metadataController.view }
        if identifier == presets { return presetController.view }
        if identifier == output { return outputController.view }
        if identifier == ocr { return ocrController.view }
        if identifier == advanced { return advancedController.view }
        return generalController.view
    }

    private func animationDuration(view: NSView, previousView: NSView?) -> TimeInterval {
        guard let previousView = previousView else { return 0 }
        return TimeInterval(abs(previousView.frame.size.height - view.frame.height)) * 0.0011
    }

    func resizeWindow(toFitView view: NSView) {
        guard let window, let contentView = window.contentView else {
            return
        }

        view.setFrameSize(view.fittingSize)

        let viewFrame = view.frame
        let windowFrame = window.frame
        let contentViewFrame = contentView.frame

        let windowWidth =  max(windowFrame.width, viewFrame.width)
        let deltaHeight = contentViewFrame.height - viewFrame.height
        let heightForWindow = windowFrame.height - deltaHeight
        let windowOriginY = windowFrame.minY + deltaHeight

        var updatedWindowFrame = windowFrame
        updatedWindowFrame.size.height = heightForWindow
        updatedWindowFrame.origin.y = windowOriginY
        updatedWindowFrame.size.width = windowWidth

        var updatedViewFrame = viewFrame
        updatedViewFrame.origin = NSPoint.zero
        updatedViewFrame.size.width = windowWidth
        if viewFrame != updatedViewFrame {
            view.frame = updatedViewFrame
        }

        if windowFrame != updatedWindowFrame {
            contentView.isHidden = true
            window.setFrame(updatedWindowFrame, display: true, animate: true)
            contentView.isHidden = false
        }
    }

    var currentView: NSView? {
        window?.contentView?.subviews.first
    }

    private func selectItem(_ item: NSToolbarItem, animate: Bool) {
        guard let window, let contentView = window.contentView else { return }

        let newView = view(for: item.itemIdentifier)
        if newView == currentView {
            return
        }

        currentView?.removeFromSuperview()

        resizeWindow(toFitView: newView)

        contentView.addSubview(newView)

        window.title = item.label
        window.makeFirstResponder(newView)
    }

    @IBAction func setPrefView(_ sender: NSToolbarItem) {
        selectItem(sender, animate: true)
    }

}
