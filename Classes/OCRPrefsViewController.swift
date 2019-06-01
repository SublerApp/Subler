//
//  OCRPrefsViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 30/05/2019.
//

import Cocoa

class OCRTableCellView : NSTableCellView {

    var item: OCRLanguage? {
        didSet {
            guard let item = item else { return }

            textField?.stringValue = item.displayName

            switch item.status {
            case .available:
                actionButton.title = NSLocalizedString("Get", comment: "")
            case .downloading:
                actionButton.title = NSLocalizedString("Cancel Download", comment: "")
            case .downloaded:
                actionButton.title = NSLocalizedString("Remove", comment: "")
            }
        }
    }

    @IBOutlet var actionButton: NSButton!

    @IBAction func buttonPressed(_ sender: Any) {
        guard let item = item else { return }

        switch item.status {
        case .available:
            OCRManager.shared.download(item: item)
        case .downloading:
            OCRManager.shared.cancelDownload(item: item)
        case .downloaded:
            try! OCRManager.shared.removeDownload(item: item)
        }
    }

}

class OCRPrefsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private let manager = OCRManager.shared

    @IBOutlet var tableView: NSTableView!
    var observer: Any?

    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("OCR", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var nibName: NSNib.Name? {
        return "OCRPrefsViewController"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.reloadData()
        observer = NotificationCenter.default.addObserver(forName: OCRManager.updateNotification,
                                                          object: nil,
                                                          queue: OperationQueue.main) { [weak self] notification in
                                                            guard let s = self else { return }
                                                            s.tableView.reloadData()
        }
    }

    // MARK: Table View

    func numberOfRows(in tableView: NSTableView) -> Int {
        return manager.languages.count
    }

    private let languageItemColumn = NSUserInterfaceItemIdentifier(rawValue: "languageItem")

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = manager.languages[row]

        if let cell = tableView.makeView(withIdentifier: languageItemColumn, owner: self) as? OCRTableCellView {
            cell.item = item
            return cell
        }

        return nil
    }

}
