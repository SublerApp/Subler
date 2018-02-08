//
//  PrefsTabViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 06/02/2018.
//

import Cocoa

class PrefsTabViewController: NSTabViewController {

    override func viewDidAppear() {
        super.viewDidAppear()
        updateWindowFrame(animated: false)
    }

    override func transition(from fromViewController: NSViewController, to toViewController: NSViewController, options: NSViewController.TransitionOptions, completionHandler completion: (() -> Void)?) {

        NSAnimationContext.runAnimationGroup({ context in

            self.updateWindowFrame(animated: true)
            super.transition(from: fromViewController, to: toViewController, options: options, completionHandler: completion)
            tabView.isHidden = true

        }, completionHandler: {
            self.tabView.isHidden = false
        })
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)

        if let window = view.window, let title = tabViewItem?.label {
            window.title = title
        }
    }

    func updateWindowFrame(animated: Bool) {

        guard let selectedItem = tabView.selectedTabViewItem, let window = view.window, let toViewController = selectedItem.viewController else {
            return
        }

        let width = max(window.frame.size.width, toViewController.view.frame.size.width)
        let contentSize = NSSize(width: width, height: toViewController.view.frame.size.height)
        let newWindowSize = window.frameRect(forContentRect: NSRect(origin: NSPoint.zero, size: contentSize)).size

        var frame = window.frame
        frame.origin.y += frame.height
        frame.origin.y -= newWindowSize.height
        frame.size = newWindowSize

        if animated {
            window.animator().setFrame(frame, display: false)
        } else {
            window.setFrame(frame, display: false)
        }
    }

}
