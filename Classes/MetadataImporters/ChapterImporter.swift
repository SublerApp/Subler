//
//  ChapterImporter.swift
//  Subler
//
//  Created by Damiano Galassi on 31/07/2017.
//

import Foundation

public protocol ChapterService {
    func search(title: String, duration: UInt64) -> [ChapterResult]
}

public enum ChapterSearch {
    case movieSeach(service: ChapterService, title: String, duration: UInt64)

    public func search(completionHandler: @escaping ([ChapterResult]) -> Void) -> Runnable {
        switch self {
        case let .movieSeach(service, title, duration):
            return RunnableTask(search: service.search(title: title, duration: duration),
                                              completionHandler: completionHandler)
        }
    }
}
