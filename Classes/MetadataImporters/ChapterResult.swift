//
//  ChapterResult.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Foundation

public struct Chapter {
    public let name: String
    public let timestamp: UInt64
}

public struct ChapterResult {
    public let title: String
    public let duration: UInt64
    public let id: UInt64
    public let confimations: UInt
    public let chapters: [Chapter]
}
