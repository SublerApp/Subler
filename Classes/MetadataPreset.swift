//
//  MetadataPreset.swift
//  Subler
//
//  Created by Damiano Galassi on 21/08/2017.
//

import Foundation

@objc(SBMetadataPreset) class MetadataPreset: NSObject, Preset {

    var pathExtension: String {
        return "sbpreset2"
    }

    enum ReplacementStrategy: Int {
        case merge
        case replace
    }

    let title: String
    @objc let metadata: MP42Metadata
    let replacementStragety: ReplacementStrategy

    let version: Int
    var changed: Bool

    @objc init(title: String, metadata: MP42Metadata) {
        self.title = title
        self.metadata = metadata
        self.replacementStragety = .merge
        self.changed = true
        self.version = 2
    }

    // MARK: NSCoding

    func encode(with aCoder: NSCoder) {
        aCoder.encode(title, forKey: "title")
        aCoder.encode(metadata, forKey: "metadata")
        aCoder.encode(version, forKey: "version")
        aCoder.encode(Int32(replacementStragety.rawValue), forKey: "replacementStragety")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let title = aDecoder.decodeObject(of: NSString.self, forKey: "title") as String?,
            let metadata = aDecoder.decodeObject(of: MP42Metadata.self, forKey: "metadata") as MP42Metadata?,
            let replacementStragety = ReplacementStrategy(rawValue: Int(aDecoder.decodeInt32(forKey: "replacementStragety")))
            else { return nil }

        let version = aDecoder.decodeInteger(forKey: "version")

        self.title = title
        self.metadata = metadata
        self.replacementStragety = replacementStragety
        self.version = version
        self.changed = false
    }

    static var supportsSecureCoding: Bool { return true }
}
