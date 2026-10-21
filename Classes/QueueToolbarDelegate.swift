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
    static let queueRemove: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "QueueRemove")
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
        } else if itemIdentifier == .queueRemove {
            return makeRemoveItem(itemIdentifier: itemIdentifier)
        }

        return nil
    }

    @MainActor private func makeRemoveItem(itemIdentifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let label = NSLocalizedString("Remove", comment: "Toolbar")
        let toolTip = NSLocalizedString("Remove items from the queue", comment: "Toolbar")

        let menu = NSMenu()
        let removeCompleted = NSMenuItem(title: NSLocalizedString("Remove completed", comment: "Toolbar"),
                                         action: #selector(QueueController.removeCompletedItems(_:)),
                                         keyEquivalent: "")
        removeCompleted.target = target
        menu.addItem(removeCompleted)

        let removeAll = NSMenuItem(title: NSLocalizedString("Remove all", comment: "Toolbar"),
                                   action: #selector(QueueController.removeAllItems(_:)),
                                   keyEquivalent: "")
        removeAll.target = target
        menu.addItem(removeAll)

        var image: NSImage?
        if #available(macOS 11, *) {
            image = NSImage(systemSymbolName: "nosign", accessibilityDescription: nil)
        }
        if image == nil {
            image = NSImage(named: "NSRemoveTemplate")
        }

        if #available(macOS 13, *) {
            let button = NSComboButton()
            button.title = ""
            button.image = image
            button.style = .unified
            button.target = target
            button.action = #selector(QueueController.removeToolbarItem(_:))
            button.menu = menu
            button.toolTip = toolTip

            let item = ButtonToolbarItem(itemIdentifier: itemIdentifier)
            item.label = label
            item.paletteLabel = label
            item.toolTip = toolTip
            item.target = target
            item.action = #selector(QueueController.removeToolbarItem(_:))
            item.view = button
            return item
        } else {
            return ButtonToolbarItem(itemIdentifier: itemIdentifier,
                                     label: label,
                                     toolTip: toolTip,
                                     image: "NSRemoveTemplate",
                                     symbolName: "nosign",
                                     target: target,
                                     action: #selector(QueueController.removeToolbarItem(_:)))
        }
    }

    @MainActor func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.queueStartStop, .space, .queueRemove, .queueSettings, .queueAdd]
    }

    @MainActor func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.queueStartStop, .queueRemove, .queueSettings, .queueAdd, .flexibleSpace, .space]
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
