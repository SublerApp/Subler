//
//  QueueToolbarDelegate.swift
//  Subler
//
//  Created by Damiano Galassi on 18/07/24.
//

import Cocoa

extension NSToolbarItem.Identifier {
    static let queueAdd: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "QueueAdd")
    static let queueSettings: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "QueueSettings")
    static let queueStartStop: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "QueueStartStop")
}

class QueueToolbarDelegate: NSObject, NSToolbarDelegate {

    weak var target: AnyObject?

    @MainActor func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        if itemIdentifier == .queueAdd {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: NSLocalizedString("Add Item", comment: "Toolbar"),
                                     toolTip: NSLocalizedString("Add an item to the queue", comment: "Toolbar"),
                                     image: "NSAddTemplate",
                                     symbolName: "doc.badge.plus",
                                     target: target,
                                     action: #selector(QueueController.open(_:)))
        } else if itemIdentifier == .queueSettings {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: NSLocalizedString("Settings", comment: "Toolbar"),
                                     toolTip: NSLocalizedString("Show/Hide settings", comment: "Toolbar"),
                                     image: "NSActionTemplate",
                                     symbolName: "gear",
                                     target: target,
                                     action: #selector(QueueController.toggleOptions(_:)))
        } else if itemIdentifier == .queueStartStop {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: NSLocalizedString("Start", comment: "Toolbar"),
                                     toolTip: NSLocalizedString("Start/Stop queue", comment: "Toolbar"),
                                     image: "playBackTemplate",
                                     symbolName: "play.fill",
                                     target: target,
                                     action: #selector(QueueController.toggleStartStop(_:)))
        }

        return nil
    }

    @MainActor func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.queueStartStop, .space, .queueSettings, .queueAdd]
    }

    @MainActor func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.queueStartStop, .queueSettings, .queueAdd, .flexibleSpace, .space]
    }

    func setState(working: Bool, toolbar: NSToolbar) {
        guard let item = toolbar.items.first(where: { $0.itemIdentifier == .queueStartStop }) else { return }

        if working {
            item.setSymbol(symbolName: "stop.fill", fallbackName: "stopTemplate")
            item.label = NSLocalizedString("Stop", comment: "Toolbar")
        } else {
            item.setSymbol(symbolName: "play.fill", fallbackName: "playBackTemplate")
            item.label = NSLocalizedString("Start", comment: "Toolbar")
        }
    }
}
