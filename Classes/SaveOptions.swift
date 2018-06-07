//
//  SaveOptions.swift
//  Subler
//
//  Created by Damiano Galassi on 08/02/2018.
//

import Cocoa
import MP42Foundation

class SaveOptions: NSViewController {

    @IBOutlet var fileFormat: NSPopUpButton!

    @IBOutlet var _64bit_data: NSButton!
    @IBOutlet var _64bit_time: NSButton!
    @IBOutlet var optimize: NSButton!

    private weak var doc: Document?
    private weak var savePanel: NSSavePanel?

    init(doc: Document, savePanel: NSSavePanel) {
        self.doc = doc
        self.savePanel = savePanel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var nibName: NSNib.Name? {
        return "SaveOptions"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let doc = doc else { return }

        let formats = doc.writableTypes(for: .saveAsOperation)
        fileFormat.removeAllItems()

        for format in formats {
            let name = UTTypeCopyDescription(format as CFString)?.takeRetainedValue() as String? ?? format
            fileFormat.addItem(withTitle: name)
        }

        let index = UserDefaults.standard.integer(forKey: "defaultSaveFormat")
        fileFormat.selectItem(at: index)

        if let format = UserDefaults.standard.string(forKey: "SBSaveFormat") {
            savePanel?.allowedFileTypes = [format]
        }

        if let filename = doc.mp4.preferredFileName() {
            savePanel?.nameFieldStringValue = filename
        }

        _64bit_data.state = UserDefaults.standard.bool(forKey: "mp464bitOffset") ? .on : .off
        _64bit_time.state = UserDefaults.standard.bool(forKey: "mp464bitTimes") ? .on : .off
        optimize.state = UserDefaults.standard.bool(forKey: "mp4SaveAsOptimize") ? .on : .off

        if doc.mp4.dataSize > 4000000000 {
            _64bit_data.state = .on
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        UserDefaults.standard.set(fileFormat.indexOfSelectedItem, forKey: "defaultSaveFormat")
        UserDefaults.standard.set(_64bit_data.state == .on, forKey: "mp464bitOffset")
        UserDefaults.standard.set(_64bit_time.state == .on, forKey: "mp464bitTimes")
        UserDefaults.standard.set(optimize.state == .on, forKey: "mp4SaveAsOptimize")
    }
    
    @IBAction func setSaveFormat(_ sender: NSPopUpButton) {
        var requiredFileType = MP42FileTypeM4V
        switch sender.indexOfSelectedItem {
        case 0:
            requiredFileType = MP42FileTypeM4V
        case 1:
            requiredFileType = MP42FileTypeMP4
        case 2:
            requiredFileType = MP42FileTypeM4A
        case 3:
            requiredFileType = MP42FileTypeM4B
        case 4:
            requiredFileType = MP42FileTypeM4R
        default:
            break
        }
        savePanel?.allowedFileTypes = [requiredFileType]
        UserDefaults.standard.set(requiredFileType, forKey: "SBSaveFormat")
    }
}
