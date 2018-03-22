//
//  PresetPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/08/2017.
//

import Cocoa

class PresetPrefsViewController: NSViewController, SectionsTableViewDataSource, SectionsTableViewDelegate, NSTextFieldDelegate {

    let presetManager: PresetManager
    var currentRow: Int

    @IBOutlet var tableView: SectionsTableView!
    @IBOutlet var removeSetButton: NSButton!
    @IBOutlet var editSetButton: NSButton!

    var controller: PresetEditorViewController?
    var observer: Any?

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "PresetPrefsViewController")
    }

    init() {
        self.currentRow = 0
        self.presetManager = PresetManager.shared
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Sets", comment: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self

        tableView.reloadData()

        observer = NotificationCenter.default.addObserver(forName: presetManager.updateNotification,
                                                          object: nil,
                                                          queue: OperationQueue.main) { [weak self] notification in
                                                            guard let s = self else { return }
                                                            s.tableView.reloadData()
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: Table View with sections

    func numberOfSections(in tableView: NSTableView) -> Int { return 2 }

    func tableView(_ tableView: NSTableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return presetManager.metadataPresets.count
        } else {
            return presetManager.queuePresets.count
        }
    }

    func tableView(_ tableView: NSTableView, viewForHeaderInSection section: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("headerCell"), owner: self) as? NSTableCellView {
            cell.textField?.stringValue = section == 0 ? "Metadata" : "Queue"
            cell.textField?.isSelectable = false
            cell.textField?.isEditable = false
            return cell
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: (section: Int, sectionRow: Int)) -> NSView? {
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("name"),
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("nameCell"), owner: self) as? NSTableCellView {
            cell.textField?.stringValue = presetManager.presets[row.sectionRow].title
            cell.textField?.isSelectable = true
            cell.textField?.isEditable = true
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeSetButton.isEnabled = tableView.selectedRow != -1
        editSetButton.isEnabled = tableView.selectedRow != -1
    }

    // MARK: UI Actions

    private func rename(preset: Preset, to title: String) {
        if title.isEmpty == false && preset.title != title {

            let copy = preset.copy() as! MetadataPreset
            copy.title = title

            do {
                try presetManager.append(newElement: copy)
                presetManager.remove(item: preset)
            }
            catch {
                view.window?.presentError(error)
            }
        }

        tableView.reloadData()
    }

    override func controlTextDidEndEditing(_ obj: Notification) {
        if let view = obj.object as? NSTextField {
            let row = tableView.row(for: view)
            let sectionRow = tableView.section(for: row)
            let preset = presetManager.presets[sectionRow.row]
            rename(preset: preset, to: view.stringValue)
        }
    }

    @IBAction func deletePreset(_ sender: Any) {
        let rowIndex = tableView.selectedRow
        if rowIndex > -1 {
            presetManager.remove(at: rowIndex)
        }
    }

    @IBAction func editPreset(_ sender: NSView) {
        let rowIndex = tableView.selectedRow
        let sectionRow = tableView.section(for: rowIndex)

        if let preset = presetManager.presets[sectionRow.row] as? MetadataPreset {
            currentRow = rowIndex
            controller = PresetEditorViewController.init(preset: preset)
            
            presentViewControllerAsSheet(controller!)
        }
    }

}
