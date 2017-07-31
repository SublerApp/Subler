//
//  ChapterResult.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Foundation

public struct Chapter {
    let name: String
    let timestamp: UInt64
}

public struct ChapterResult {
    let title: String
    let duration: UInt64
    let confimations: UInt
    let chapters: [Chapter]
}
