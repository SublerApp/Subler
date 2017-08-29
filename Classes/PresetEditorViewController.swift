//
//  PresetEditorViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 29/08/17.
//

import Cocoa

class PresetEditorViewController: SBMovieViewController {

    let preset: MetadataPreset
    @IBOutlet weak var presetTitle: NSTextField!
    @IBOutlet weak var replaceArtworks: NSButton!
    @IBOutlet weak var replaceAnnotations: NSButton!

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "PresetEditorViewController")
    }

    init(preset: MetadataPreset) {
        self.preset = preset
        super.init(nibName: self.nibName, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.metadata = preset.metadata

        super.loadView()

        view.appearance = NSAppearance(named: .aqua)
        presetTitle.stringValue = preset.title

        preset.changed = true
        replaceArtworks.state = preset.replaceArtworks == true ? .on : .off
        replaceAnnotations.state = preset.replaceAnnotations == true ? .on : .off
    }

    @IBAction func setReplaceArtworksState(_ sender: NSButton) {
        preset.replaceArtworks = sender.state == .on ? true : false
    }

    @IBAction func setReplaceAnnotationsState(_ sender: NSButton) {
        preset.replaceAnnotations = sender.state == .on ? true : false
    }
}
