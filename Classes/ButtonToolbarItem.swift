//
//  ButtonToolbarItem.swift
//  Subler
//
//  Created by Damiano Galassi on 20/10/2017.
//

import Cocoa

extension NSToolbarItem {
    func setSymbol(symbolName: String?, fallbackName: String) {
        var image: NSImage?

        if #available(macOS 11, *) {
            if let symbolName {
                image = NSImage.init(systemSymbolName: symbolName, accessibilityDescription: nil)
                if image == nil {
                    image = NSImage(named: symbolName)
                }
            }
        }

        if image == nil {
            image = NSImage(named: fallbackName)
        }

        self.image = image
    }
}

final class ButtonToolbarItem : NSToolbarItem {

    override init(itemIdentifier: NSToolbarItem.Identifier) {
        super.init(itemIdentifier: itemIdentifier)
    }

    init(itemIdentifier: NSToolbarItem.Identifier, label: String, toolTip: String, image: String, symbolName: String? = nil, target: AnyObject?, action: Selector) {
        super.init(itemIdentifier: itemIdentifier)

        self.label = label
        self.paletteLabel = label
        self.toolTip = toolTip
        self.target = target
        self.action = action
        self.setSymbol(symbolName: symbolName, fallbackName: image)

        if #available(macOS 14, *) {
            self.isBordered = true
        } else {
            let button = NSButton.init(image: self.image!, target: self.target, action: self.action)
            button.isBordered = true
            button.bezelStyle = .toolbar

            if #available(macOS 11, *) {
                self.isBordered = true
                let views =  ["button" : button];
                let constraint = NSLayoutConstraint.constraints(withVisualFormat: "H:[button(>=40)]",
                                                                options: [], metrics: nil, views: views)
                NSLayoutConstraint.activate(constraint)
            } else {
                self.minSize = NSMakeSize(32, 16)
            }

            self.view = button
        }
    }

    override func validate() {
        guard let action else { return }

        if let target = NSApplication.shared.target(forAction: action, to: target, from: self) as? AnyObject {
            if target.responds(to: #selector(NSUserInterfaceValidations.validateUserInterfaceItem(_:))) {
                self.isEnabled = target.validateUserInterfaceItem(self)
            } else if target.responds(to: #selector(NSToolbarItemValidation.validateToolbarItem(_:))) {
                self.isEnabled = target.validateToolbarItem(self)
            } else {
                super.validate()
            }
        } else {
            super.validate()
        }
    }

    override var menuFormRepresentation: NSMenuItem? {
        get {
            if let menu = self.view?.menu {
                let menuItem = NSMenuItem()
                menuItem.title = self.label

                if menu.numberOfItems > 0 {
                    menuItem.submenu = menu
                } else {
                    menuItem.action = self.action
                }

                return menuItem
            } else {
                return NSMenuItem(title: self.label, action: self.action, keyEquivalent: "")
            }
        }
        set (menuItem) {
            super.menuFormRepresentation = menuItem
        }
    }
}
