//
//  DocumentToolbarDelegate.swift
//  Subler
//
//  Created by Damiano Galassi on 18/07/24.
//

import Cocoa

private extension NSToolbarItem.Identifier {
    static let importTracks: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "AddTracks")
    static let deleteTracks: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "DeleteTracks")
    static let actions: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "Actions")
    static let searchMetadata: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "SearchMetadata")
    static let sendToQueue: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "SendToQueue")
    static let showQueue: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "ShowQueue")
}

class DocumentToolbarDelegate: NSObject, NSToolbarDelegate {

    weak var target: AnyObject?

    @MainActor func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        if itemIdentifier == .importTracks {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: NSLocalizedString("Import", comment: "Toolbar"),
                                     toolTip: NSLocalizedString("Import tracks from external files", comment: "Toolbar"),
                                     image: "NSAddTemplate",
                                     symbolName: "doc.badge.plus",
                                     target: target,
                                     action: #selector(DocumentWindowController.selectFile(_:)))
        } else if itemIdentifier == .deleteTracks {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: NSLocalizedString("Delete", comment: "Toolbar"),
                                     toolTip: NSLocalizedString("Delete the selected track", comment: "Toolbar"),
                                     image: "NSRemoveTemplate",
                                     symbolName: "nosign",
                                     target: target,
                                     action: #selector(DocumentWindowController.deleteTrack(_:)))
        } else if itemIdentifier == .actions {
            let submenu = NSMenu()

            let menuItem = NSMenuItem()
            menuItem.title = NSLocalizedString("At the Beginning", comment: "Toolbar")
            menuItem.action =  #selector(DocumentWindowController.addChaptersEvery(_:))
            menuItem.tag = -1
            submenu.addItem(menuItem)

            for minutes in [1, 2, 5, 10, 15, 20, 30] {
                let menuItem = NSMenuItem()
                let title = minutes == 1 ? NSLocalizedString("1 minute", comment: "Toolbar") :
                                        String(format: NSLocalizedString("%@ minutes", comment: "Toolbar"), "\(minutes)")

                menuItem.title = title
                menuItem.action =  #selector(DocumentWindowController.addChaptersEvery(_:))
                menuItem.tag = minutes
                submenu.addItem(menuItem)
            }

            let chapters = NSMenuItem()
            chapters.title = NSLocalizedString("Insert a chapter every", comment: "Toolbar")
            chapters.submenu = submenu

            let menu = NSMenu()
            menu.addItem(chapters)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: NSLocalizedString("Organize alternate groups", comment: "Toolbar"),
                         action: #selector(DocumentWindowController.iTunesFriendlyTrackGroups(_:)),
                         keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("Clear tracks names", comment: "Toolbar"),
                         action: #selector(DocumentWindowController.clearTrackNames(_:)),
                         keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("Prettify audio track names", comment: "Toolbar"),
                         action: #selector(DocumentWindowController.prettifyAudioTrackNames(_:)),
                         keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("Fix audio fallbacks", comment: "Toolbar"),
                         action: #selector(DocumentWindowController.fixAudioFallbacks(_:)),
                         keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: NSLocalizedString("Offset…", comment: "Toolbar"),
                         action: #selector(DocumentWindowController.showTrackOffsetSheet(_:)),
                         keyEquivalent: "")

            let label = NSLocalizedString("Action", comment: "Toolbar")

            if #available(macOS 10.15, *) {
                let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
                item.label = label
                item.paletteLabel = label
                item.toolTip = NSLocalizedString("Perform tasks with the selected items", comment: "Toolbar")
                if #available(macOS 26.0, *) {
                    item.showsIndicator = false
                    item.image = NSImage.init(systemSymbolName: "ellipsis", accessibilityDescription: nil)
                } else if #available(macOS 26.0, *) {
                    item.image = NSImage.init(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil)
                } else {
                    item.image = NSImage(named:"NSActionTemplate")
                }
                item.menu = menu
                return item
            } else {
                let imageItem = NSMenuItem()
                imageItem.image = NSImage(named:"NSActionTemplate")
                imageItem.title = ""
                menu.insertItem(imageItem, at: 0)

                let popUpButton = NSPopUpButton()
                popUpButton.bezelStyle = .toolbar
                popUpButton.pullsDown = true
                popUpButton.menu = menu

                let item = ButtonToolbarItem(itemIdentifier: itemIdentifier)
                item.label = label
                item.paletteLabel = label
                item.toolTip = NSLocalizedString("Perform tasks with the selected items", comment: "Toolbar")
                item.view = popUpButton
                item.minSize = NSSize(width: 48, height: 16)

                return item
            }
        } else if itemIdentifier == .searchMetadata {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: NSLocalizedString("Search Metadata", comment: "Toolbar"),
                                     toolTip: NSLocalizedString("Search metadata on the web", comment: "Toolbar"),
                                     image: "NSRevealFreestandingTemplate",
                                     symbolName: "doc.text.magnifyingglass",
                                     target: target,
                                     action: #selector(DocumentWindowController.searchMetadata(_:)))
        } else if itemIdentifier == .sendToQueue {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: NSLocalizedString("Send to Queue", comment: "Toolbar"),
                                     toolTip: NSLocalizedString("Send the current document to the queue", comment: "Toolbar"),
                                     image: "ToolbarActionTemplate",
                                     symbolName: "photo.badge.plus",
                                     target: target,
                                     action: #selector(Document.sendToQueue(_:)))
        } else if itemIdentifier == .showQueue {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: NSLocalizedString("Queue", comment: "Toolbar"),
                                     toolTip: NSLocalizedString("Show the Queue window", comment: "Toolbar"),
                                     image: "ToolbarActionTemplate",
                                     symbolName: "photo.stack",
                                     target: nil,
                                     action: #selector(AppDelegate.showQueueWindow(_:)))
        }

        return nil
    }

    @MainActor func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.importTracks, .searchMetadata, .actions, .space, .deleteTracks, .flexibleSpace, .sendToQueue, .showQueue,]
    }

    @MainActor func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.importTracks, .deleteTracks, .actions, .searchMetadata, .sendToQueue, .showQueue, .flexibleSpace, .space]
    }

}
