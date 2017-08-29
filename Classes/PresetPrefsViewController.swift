//
//  PresetPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/08/2017.
//

import Cocoa

class PresetPrefsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    let presetManager: PresetManager
    var popover: NSPopover?
    var currentRow: Int

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var removeSetButton: NSButton!

    var controller: PresetEditorViewController?
    var observer: Any?

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "SBPresetPrefsViewController")
    }

    init() {
        self.currentRow = 0
        self.presetManager = PresetManager.shared
        super.init(nibName: self.nibName, bundle: nil)
    }

    override func loadView() {
        super.loadView()

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

    // MARK: Table View data source

    func numberOfRows(in tableView: NSTableView) -> Int {
        return presetManager.presets.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("name"),
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("nameCell"), owner: self) as? NSTableCellView {
            cell.textField?.stringValue = presetManager.presets[row].title
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeSetButton.isEnabled = tableView.selectedRow != -1
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
            let preset = presetManager.presets[row]
            rename(preset: preset, to: view.stringValue)
        }
    }

    @IBAction func deletePreset(_ sender: Any) {
        closePopOver(self)

        let rowIndex = tableView.selectedRow
        if rowIndex > -1 {
            presetManager.remove(at: rowIndex)
        }
    }

    @IBAction func closePopOver(_ sender: Any) {
        guard let currentPopover = popover else { return }

        currentPopover.close()
        popover = nil
        controller = nil
    }

    @IBAction func toggleInfoWindow(_ sender: NSView) {
        let rowIndex = tableView.row(for: sender)

        if currentRow == rowIndex && popover != nil {
            closePopOver(self)
        }
        else {
            closePopOver(self)

            if let preset = presetManager.presets[rowIndex] as? MetadataPreset {
                currentRow = rowIndex

                controller = PresetEditorViewController.init(preset: preset)

                popover = NSPopover()
                popover?.contentViewController = controller
                popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.maxY)
            }
        }

    }

}
