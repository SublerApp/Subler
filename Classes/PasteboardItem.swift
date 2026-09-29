//
//  PasteboardItem.swift
//  Subler
//
//  Created by Damiano Galassi on 22/09/2026.
//

import Cocoa

extension NSPasteboard.PasteboardType {
    static let tableViewIndex = NSPasteboard.PasteboardType("org.subler.tableViewIndex")
}

class PasteboardItem: NSObject, NSPasteboardWriting {
    let index: Int
    let type: NSPasteboard.PasteboardType

    init(index: Int, type: NSPasteboard.PasteboardType) {
        self.index = index
        self.type = type
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [type]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case self.type:
            return index
        default:
            return nil
        }
    }
}

extension NSPasteboardItem {
    func integer(forType type: NSPasteboard.PasteboardType) -> Int? {
        guard let data = data(forType: type) else { return nil }
        let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: .mutableContainers,
            format: nil)
        return plist as? Int
    }
}

extension Array {
    mutating func move(from start: Index, to end: Index) {
        guard (0..<count) ~= start, (0...count) ~= end else { return }
        if start == end { return }
        let targetIndex = start < end ? end - 1 : end
        insert(remove(at: start), at: targetIndex)
    }

    mutating func move(with indexes: IndexSet, to toIndex: Index) {
        let movingData = indexes.map{ self[$0] }
        let targetIndex = toIndex - indexes.filter{ $0 < toIndex }.count
        for (i, e) in indexes.enumerated() {
            remove(at: e - i)
        }
        insert(contentsOf: movingData, at: targetIndex)
    }
}
