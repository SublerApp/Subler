//
//  PresetPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 20/08/2017.
//

import Cocoa

class PresetPrefsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    let presetManager: PresetManager
    var popover: NSPopover?
    var currentRow: Int

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var removeSetButton: NSButton!

    var controller: SBMovieViewController?
    var observer: Any?

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "SBSetPrefsViewController")
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

                controller = SBMovieViewController.init(nibName: NSNib.Name(rawValue: "MovieView"), bundle: nil)
                controller?.metadata = preset.metadata

                popover = NSPopover()
                popover?.contentViewController = controller
                popover?.contentSize = NSMakeSize(480, 500)

                popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.maxY)
            }
        }

    }

}
