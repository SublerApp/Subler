//
//  ViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 07/08/2019.
//

import Cocoa

class ViewController: NSViewController, NSWindowDelegate {

    // MARK: - Interface Builder

    @IBInspectable var autosave: String?

    // MARK: - NSViewController

    override func viewWillAppear() {
        super.viewWillAppear()

        guard let window = self.view.window, let saveName = autosave else { return }

        window.delegate = self
        window.setFrameUsingName(saveName)
    }

    // MARK: - NSWindowDelegate

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let saveName = autosave else {
            return
        }
        self.view.window?.saveFrame(usingName: saveName)
    }
}
