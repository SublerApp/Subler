//
//  Queue.swift
//  Subler
//
//  Created by Damiano Galassi on 27/01/2019.
//

import Foundation
import IOKit

extension SBQueueItem {

    @objc func updateProgress(_ progress: Double) {
        if let queue = delegate as? Queue {
            queue.updateProgress(progress)
        }
    }
}

class Queue {

    static let Working = NSNotification.Name(rawValue: "QueueWorkingNotification")
    static let Completed = NSNotification.Name(rawValue: "QueueCompletedNotification")
    static let Failed = NSNotification.Name(rawValue: "QueueFailedNotification")
    static let Cancelled = NSNotification.Name(rawValue: "QueueCancelledNotification")

    private let workQueue: DispatchQueue
    private let arrayQueue: DispatchQueue

    private var sleepAssertion: IOPMAssertionID = IOPMAssertionID(0)
    private var sleepAssertionSuccess: IOReturn = kIOReturnInvalid

    private var items: [SBQueueItem]

    private var cancelled: Bool
    private var currentItem: SBQueueItem?

    private let url: URL

    enum Status {
        case unknown
        case working
        case completed
    }

    init(url queueURL: URL) {
        url = queueURL
        statusInternal = .unknown
        cancelled = false

        workQueue = DispatchQueue(label: "org.subler.WorkQueue")
        arrayQueue = DispatchQueue(label: "org.subler.SaveQueue")

        if let data = try? Data(contentsOf: url) {
            let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
            unarchiver.requiresSecureCoding = true

            items = unarchiver.decodeObject(of: [NSArray.classForCoder(), NSMutableArray.classForCoder(), SBQueueItem.classForCoder()], forKey: NSKeyedArchiveRootObjectKey) as! [SBQueueItem]
            unarchiver.finishDecoding()
        } else {
            items = Array()
        }

        for item in items where item.status == .working {
            item.status = .failed
        }
    }

    func saveToDisk() throws {
        arrayQueue.sync {
            let data = NSMutableData()
            let archiver = NSKeyedArchiver(forWritingWith: data)
            archiver.requiresSecureCoding = true
            archiver.encode(items, forKey: NSKeyedArchiveRootObjectKey)
            archiver.finishEncoding()

            data.write(to: url, atomically: true)
        }
    }

    /// Starts the queue.
    func start() {
        arrayQueue.sync {
            if self.statusInternal == .working || self.cancelled {
                return
            } else {
                self.statusInternal = .working
            }
        }

        workQueue.async {
            self.arrayQueue.sync {
                self.cancelled = false
            }
            self.disableSleep()

            var completed: UInt = 0
            var failed: UInt = 0

            while(true) {
                try? self.saveToDisk()

                if let currentItem = self.firstItemInQueue {
                    self.arrayQueue.sync {
                        self.currentItem = currentItem
                    }

                    let currentIndex = self.index(of: currentItem)
                    currentItem.status = .working
                    currentItem.delegate = self

                    self.handleSBStatusWorking(progress: 0, index: currentIndex)
                    do {
                        try currentItem.process()
                    } catch {
                        currentItem.status = .failed
                        failed += 1
                        self.handleSBStatusFailed(error: error)
                    }

                    var cancelled = false
                    self.arrayQueue.sync {
                        cancelled = self.cancelled
                    }

                    currentItem.delegate = nil
                    self.arrayQueue.sync {
                        self.currentItem = nil
                    }

                    if cancelled {
                        currentItem.status = .cancelled
                        self.handleSBStatusCancelled()
                        break
                    } else {
                        currentItem.status = .completed
                        completed += 1
                    }

                    self.handleSBStatusWorking(progress: 100, index: currentIndex)
                } else {
                    break
                }
            }
            self.enableSleep()
            self.arrayQueue.sync {
                self.statusInternal = .completed
            }
            self.handleSBStatusCompleted(completed: completed, failed: failed)
        }
    }

    /// Stops the queue and abort the current work.
    func stop() {
        arrayQueue.sync {
            currentItem?.cancel()
            cancelled = true
        }
    }

    private var statusInternal: Status

    var status: Status {
        get {
            var status: Status = .completed
            arrayQueue.sync {
                status = self.statusInternal
            }
            return status
        }
    }

    var count: Int {
        get {
            var count = 0
            arrayQueue.sync {
                count = items.count
            }
            return count
        }
    }

    var readyCount: Int {
        get {
            var count = 0
            arrayQueue.sync {
                count = items.filter { $0.status == .ready }.count
            }
            return count
        }
    }

    private var firstItemInQueue: SBQueueItem? {
        get {
            var first: SBQueueItem?
            arrayQueue.sync {
                first = items.first(where: { (item) -> Bool in
                    return item.status != .completed && item.status != .failed
                })
                first?.status = .working
            }
            return first
        }
    }

    //MARK: Item management

    func append(_ item: SBQueueItem) {
        arrayQueue.sync {
            items.append(item)
        }
    }

    func item(at index: Int) -> SBQueueItem {
        var result: SBQueueItem?
        arrayQueue.sync {
            result = items[index]
        }
        return result!
    }

    func items(at indexes: IndexSet) -> [SBQueueItem] {
        var result: [SBQueueItem] = Array()
        arrayQueue.sync {
            result = items.enumerated().filter { indexes.contains($0.offset) == true } .map { $0.element }
        }
        return result
    }

    func index(of item: SBQueueItem) -> Int {
        var index = -1
        arrayQueue.sync {
            index = items.firstIndex(of: item) ?? -1
        }
        return index
    }

    func indexesOfItems(with status: SBQueueItemStatus) -> IndexSet {
        var indexes: [Int] = Array()
        arrayQueue.sync {
            indexes = items.enumerated().filter { $0.element.status == status } .map { $0.offset }
        }
        return IndexSet(indexes)
    }

    func insert(_ item: SBQueueItem, at index: Int) {
        arrayQueue.sync {
            items.insert(item, at: index)
        }
    }

    func remove(at indexes: IndexSet) {
        arrayQueue.sync {
            items = items.enumerated().filter { indexes.contains($0.offset) == false } .map { $0.element }
        }
    }

    func swapAt(_ i: Int, _ j: Int) {
        arrayQueue.sync {
            items.swapAt(i, j)
        }
    }

    func remove(_ item: SBQueueItem) {
        arrayQueue.sync {
            if let index = items.firstIndex(of: item) {
                items.remove(at: index)
            }
        }
    }

    func removeCompletedItems() -> IndexSet {
        var indexes: [Int] = Array()
        arrayQueue.sync {
            indexes = items.enumerated().filter { $0.element.status == .completed } .map { $0.offset }
            items = items.enumerated().filter { indexes.contains($0.offset) == false } .map { $0.element }
        }
        return IndexSet(indexes)
    }

    //MARK: Sleep

    private func disableSleep() {
        sleepAssertionSuccess = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                                            IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                            "Subler Queue" as CFString,
                                                            &sleepAssertion)
    }

    private func enableSleep() {
        if sleepAssertionSuccess == kIOReturnSuccess {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertionSuccess = kIOReturnInvalid
            sleepAssertion = IOPMAssertionID(0)
        }
    }

    // MARK: Notifications

    func updateProgress(_ progress: Double) {
        handleSBStatusWorking(progress: progress, index: -1)
    }

    /// Processes SBQueueStatusWorking state information. Current implementation just
    /// sends SBQueueWorkingNotification.
    private func handleSBStatusWorking(progress: Double, index: Int) {
        let itemDescription = currentItem?.localizedWorkingDescription ?? NSLocalizedString("Working", comment: "Queue Working.")
        let info = String.localizedStringWithFormat(NSLocalizedString("%@, item %ld.", comment: ""), itemDescription, index + 1)

        NotificationCenter.default.post(name: Queue.Working, object: self, userInfo: ["ProgressString": info, "Progress": progress, "ItemIndex": index])
    }

    /// Processes SBQueueStatusCompleted state information. Current implementation just
    /// sends SBQueueCompletedNotification.
    private func handleSBStatusCompleted(completed: UInt, failed: UInt) {
        NotificationCenter.default.post(name: Queue.Completed, object: self, userInfo: ["CompletedCount": completed, "FailedCount": failed])
    }

    /// Processes SBQueueStatusFailed state information. Current implementation just
    /// sends SBQueueFailedNotification.
    private func handleSBStatusFailed(error: Error) {
        NotificationCenter.default.post(name: Queue.Failed, object: self, userInfo: ["Error": error])
    }

    /// Processes SBQueueStatusCancelled state information. Current implementation just
    /// sends SBQueueCancelledNotification.
    private func handleSBStatusCancelled() {
        NotificationCenter.default.post(name: Queue.Cancelled, object: self)
    }

}
