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
    @IBOutlet weak var replacementStrategy: NSPopUpButton!
    
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
        replacementStrategy.selectItem(withTag: preset.replacementStragety.rawValue)
        
        preset.changed = true
    }

    @IBAction func setReplacementStragety(_ sender: NSPopUpButton) {
        if let newStragety = MetadataPreset.ReplacementStrategy(rawValue: sender.selectedTag()) {
           preset.replacementStragety = newStragety
        }
    }
}
