//
//  ItemViewController.swift
//  Subler
//
//  Created by Damiano Galassi on 11/11/2017.
//

import Cocoa

protocol ItemViewDelegate: AnyObject {
    @MainActor func edit(item: QueueItem)
}

final class ItemViewController : NSViewController {

    @objc dynamic let item: QueueItem
    
    @objc dynamic let name: String
    @objc dynamic let path: String
    @objc dynamic var destPath: String

    private var delegate: ItemViewDelegate

    private var statusObserver: NSKeyValueObservation?
    private var actionsObserver: NSKeyValueObservation?

    @IBOutlet var editButton: NSButton!
    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var tableHeight: NSLayoutConstraint!
    @IBOutlet var tableView: NSTableView!

    override var nibName: NSNib.Name? {
        return "QueueItem"
    }

    init(item: QueueItem, delegate: ItemViewDelegate) {
        self.item = item
        self.name = item.fileURL.lastPathComponent
        self.path = item.fileURL.path
        self.destPath = item.destURL.path
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.deselectAll(self)

        // Observe the item status
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, change in
            guard let s = self else { return }
            DispatchQueue.main.async {
                s.destPath = observed.destURL.path

                if observed.status == .ready || observed.status == .completed {
                    s.editButton.isEnabled = true
                } else {
                    s.editButton.isEnabled = false
                }
            }
        }

        // Observe the item actions
        actionsObserver = item.observe(\.actions, options: [.initial, .new, .old]) { [weak self] observed, change in
            guard let s = self, let newCount = change.newValue?.count else { return }
            let count = newCount - (change.oldValue?.count ?? 0)
            let height = 16.0 * CGFloat(count >= 0 ? count : 1)
            DispatchQueue.main.async {
                s.tableHeight.constant = height
            }
        }
    }

    @IBAction func edit(_ sender: Any) {
        spinner.isHidden = false
        delegate.edit(item: item)
    }
}
