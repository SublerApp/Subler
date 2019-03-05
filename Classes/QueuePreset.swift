//
//  QueuePreset.swift
//  Subler
//
//  Created by Damiano Galassi on 21/08/2017.
//

import Foundation

final class QueuePreset: Preset {

    var title: String
    let options: [String : Any]

    let version: Int
    var changed: Bool

    var pathExtension: String {
        return "sbqueuepreset"
    }

    init(title: String, options: [String : Any]) {
        self.title = title
        self.options = options
        self.changed = true
        self.version = 1
    }

    // MARK: NSCoding

    static var supportsSecureCoding: Bool {
        return true
    }

    func encode(with aCoder: NSCoder) {

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    // MARK: NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        return QueuePreset(title: title, options: options)
    }

}
