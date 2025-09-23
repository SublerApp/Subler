//
//  SaveOptions.swift
//  Subler
//
//  Created by Damiano Galassi on 08/02/2018.
//

import Cocoa
import MP42Foundation
import UniformTypeIdentifiers

final class SaveOptions: NSViewController {

    @IBOutlet var fileFormat: NSPopUpButton!

    @IBOutlet var _64bit_data: NSButton!
    @IBOutlet var _64bit_time: NSButton!
    @IBOutlet var optimize: NSButton!

    private weak var doc: Document?
    private weak var savePanel: NSSavePanel?
    
    private static let fileTypes = [MP42FileTypeM4V, MP42FileTypeMP4, MP42FileTypeM4A, MP42FileTypeM4B, MP42FileTypeM4R]

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
    
    private func setUpFileFormats()
    {
        guard let doc = doc else { return }
        
        let types = doc.writableTypes(for: .saveAsOperation)

        fileFormat.removeAllItems()
        
        for type in types {
            let name = UTTypeCopyDescription(type as CFString)?.takeRetainedValue() as String? ?? type
            fileFormat.addItem(withTitle: name)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpFileFormats()
        
        guard let doc = doc else { return }
        
        let fileType = Prefs.fileType
        let index = SaveOptions.fileTypes.firstIndex(of: fileType) ?? 1
        fileFormat.selectItem(at: index)

        if let filename = doc.mp4.preferredFileName() {
            savePanel?.nameFieldStringValue = filename
        }

        setFileType(filenameExtension: fileType)

        _64bit_data.state = Prefs.mp464bitOffset ? .on : .off
        _64bit_time.state = Prefs.mp464bitTimes ? .on : .off
        optimize.state = Prefs.mp4SaveAsOptimize ? .on : .off

        if doc.mp4.dataSize > 3900000000 {
            _64bit_data.state = .on
        }
    }

    func saveUserDefaults() {
        Prefs.fileType = SaveOptions.fileTypes[fileFormat.indexOfSelectedItem]
        Prefs.mp464bitOffset = _64bit_data.state == .on
        Prefs.mp464bitTimes = _64bit_time.state == .on
        Prefs.mp4SaveAsOptimize = optimize.state == .on
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        saveUserDefaults()
    }

    func setFileType(filenameExtension: String)
    {
        if #available(macOS 15.0, *) {
            let type = UTType(filenameExtension: filenameExtension) ?? .mpeg4Movie
            savePanel?.currentContentType = type
        } else {
            savePanel?.allowedFileTypes = [filenameExtension]
        }
    }

    @IBAction func setSaveFormat(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        let selectedFileType = SaveOptions.fileTypes.indices.contains(index) ?
                                SaveOptions.fileTypes[index] : MP42FileTypeMP4
        
        setFileType(filenameExtension: selectedFileType)
    }
}
