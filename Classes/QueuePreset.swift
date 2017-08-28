//
//  QueuePreset.swift
//  Subler
//
//  Created by Damiano Galassi on 21/08/2017.
//

import Foundation

class QueuePreset: NSObject, Preset {

    let title: String
    let options: [String:Any]

    let version: Int
    var changed: Bool

    var pathExtension: String {
        return "sbqueuepreset"
    }

    init(title: String, options: [String:Any]) {
        self.title = title
        self.options = options
        self.changed = true
        self.version = 2
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

}
