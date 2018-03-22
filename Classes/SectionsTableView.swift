//
//  SectionsTableView.swift
//  Subler
//
//  Created by Damiano Galassi on 20/03/2018.
//

import Cocoa

protocol SectionsTableViewDataSource: NSTableViewDataSource {
    func numberOfSections(in tableView: NSTableView) -> Int
    func tableView(_ tableView: NSTableView, numberOfRowsInSection section: Int) -> Int
}

private class SectionsTableViewDataSourceImplementation: NSObject, NSTableViewDataSource {

    fileprivate init(dataSource: SectionsTableViewDataSource) {
        self.wrappedDataSource = dataSource
    }

    fileprivate weak var wrappedDataSource: SectionsTableViewDataSource?

    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let wrappedDataSource = wrappedDataSource else { return 0 }
        var total = 0

        for section in 0..<wrappedDataSource.numberOfSections(in: tableView) {
            let count = wrappedDataSource.tableView(tableView, numberOfRowsInSection: section)
            total += count > 0 ? count + 1 : 0
        }

        return total
    }

}

protocol SectionsTableViewDelegate: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewForHeaderInSection section: Int) -> NSView?
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: (section: Int, sectionRow: Int)) -> NSView?
}

private class SectionsTableViewDelegateImplementation: NSObject, NSTableViewDelegate {

    fileprivate init(delegate: SectionsTableViewDelegate) {
        self.wrappedDelegate = delegate
    }

    fileprivate weak var wrappedDelegate: SectionsTableViewDelegate?

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let wrappedDelegate = wrappedDelegate,
            let tableView = tableView as? SectionsTableView else { return nil }
        let (section, sectionRow) = tableView.section(for: row)

        if sectionRow == -1 {
            return wrappedDelegate.tableView(tableView, viewForHeaderInSection: section)
        } else {
            return wrappedDelegate.tableView(tableView, viewFor: tableColumn, row: (section, sectionRow))
        }
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard let tableView = tableView as? SectionsTableView else { return false }

        let (_, sectionRow) = tableView.section(for: row)
        return sectionRow == -1
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if let tableView = tableView as? SectionsTableView {
            let (_
            , sectionRow) = tableView.section(for: row)

            if sectionRow == -1 {
                return false
            }

            return true
        }
        return false
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        wrappedDelegate?.tableViewSelectionDidChange!(notification)
    }
}

/// A Table View with iOS-like section headers
class SectionsTableView: ExpandedTableView {

    private var strongDataSource: SectionsTableViewDataSourceImplementation?
    private var strongDelegate: SectionsTableViewDelegateImplementation?

    override var dataSource: NSTableViewDataSource? {
        set(newDataSource) {
            if newDataSource != nil {
                strongDataSource = SectionsTableViewDataSourceImplementation(dataSource: newDataSource as! SectionsTableViewDataSource)
                super.dataSource = strongDataSource
            } else {
                strongDataSource = nil
                super.dataSource = nil
            }
        }
        get {
            return super.dataSource
        }
    }

    override var delegate: NSTableViewDelegate? {
        set(newDelegate) {
            if newDelegate != nil {
                strongDelegate = SectionsTableViewDelegateImplementation(delegate: newDelegate as! SectionsTableViewDelegate)
                super.delegate = strongDelegate
            } else {
                strongDelegate = nil
                super.delegate = nil
            }
        }
        get {
            return super.delegate
        }
    }

    private func sectionForRow(row: Int, counts: [Int]) -> (section: Int?, sectionRow: Int?) {
        var c = counts[0]
        for section in 0..<counts.count {
            if (section > 0) {
                c = c + counts[section]
            }
            if (row >= c - counts[section]) && row < c {
                return (section: section, sectionRow: row - (c - counts[section]) - 1)
            }
        }

        return (section: nil, sectionRow: nil)
    }

    func section(for row: Int) -> (section: Int, sectionRow: Int) {
        guard let wrappedDataSource = strongDataSource?.wrappedDataSource else { return (section: 0, sectionRow: 0) }

        let numberOfSections = wrappedDataSource.numberOfSections(in: self)
        var counts = [Int](repeating: 0, count: numberOfSections)

        for section in 0..<numberOfSections {
            let count = wrappedDataSource.tableView(self, numberOfRowsInSection: section)
            counts[section] = count > 0 ? count + 1 : 0
        }

        let result = sectionForRow(row: row, counts: counts)
        return (section: result.section ?? 0, sectionRow: result.sectionRow ?? 0)
    }

}
