//
//  SaveOptions.swift
//  Subler
//
//  Created by Damiano Galassi on 08/02/2018.
//

import Cocoa

class SaveOptions: NSViewController {

    @IBOutlet var fileFormat: NSPopUpButton!

    @IBOutlet var _64bit_data: NSButton!
    @IBOutlet var _64bit_time: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        let index = UserDefaults.standard.integer(forKey: "defaultSaveFormat")
        fileFormat.selectItem(at: index)

        _64bit_data.state = UserDefaults.standard.bool(forKey: "mp464bitOffset") ? .on : .off
        _64bit_time.state = UserDefaults.standard.bool(forKey: "mp464bitTimes") ? .on : .off
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        UserDefaults.standard.set(fileFormat.indexOfSelectedItem, forKey: "defaultSaveFormat")
        UserDefaults.standard.set(_64bit_data.state == .on, forKey: "mp464bitOffset")
        UserDefaults.standard.set(_64bit_time.state == .on, forKey: "mp464bitTimes")
    }
    
}
