//
//  SaveOptions.swift
//  Subler
//
//  Created by Damiano Galassi on 08/02/2018.
//

import Cocoa
import MP42Foundation

final class SaveOptions: NSViewController {

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

        fileFormat.selectItem(at: Prefs.defaultSaveFormat)
        savePanel?.allowedFileTypes = [Prefs.saveFormat]

        if let filename = doc.mp4.preferredFileName() {
            savePanel?.nameFieldStringValue = filename
        }

        _64bit_data.state = Prefs.mp464bitOffset ? .on : .off
        _64bit_time.state = Prefs.mp464bitTimes ? .on : .off
        optimize.state = Prefs.mp4SaveAsOptimize ? .on : .off

        if doc.mp4.dataSize > 3900000000 {
            _64bit_data.state = .on
        }
    }

    func saveUserDefaults()
    {
        Prefs.defaultSaveFormat = fileFormat.indexOfSelectedItem
        Prefs.mp464bitOffset = _64bit_data.state == .on
        Prefs.mp464bitTimes = _64bit_time.state == .on
        Prefs.mp4SaveAsOptimize = optimize.state == .on
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        saveUserDefaults()
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
        Prefs.saveFormat = requiredFileType
    }
}
