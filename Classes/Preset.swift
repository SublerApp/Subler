//
//  Preset.swift
//  Subler
//
//  Created by Damiano Galassi on 21/08/2017.
//

import Foundation

@objc protocol Preset: AnyObject, NSSecureCoding {
    var title: String { get }
    var changed: Bool { get }
    var version: Int { get }

    var pathExtension: String { get }
}

extension Preset {

    private func appSupportURL() -> URL? {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Subler")
    }

    var fileURL: URL {
        guard let url = appSupportURL() else { fatalError() }
        return url.appendingPathComponent(title).appendingPathExtension(pathExtension)
    }
}
