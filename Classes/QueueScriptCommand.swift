//
//  QueueScriptCommand.swift
//  Subler
//
//  Created by Damiano Galassi on 16/03/2018.
//

import Foundation

@objc(SBQueueScriptCommand) class QueueScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        guard let args = directParameter as? [URL] else { return nil }
        QueueController.shared.insert(contentOf: args, at: QueueController.shared.count)
        return nil
    }

}

@objc(SBQueueStartAndWaitScriptCommand) class QueueStartAndWaitScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        QueueController.shared.add(script: self)
        QueueController.shared.start(self)
        self.suspendExecution()
        return nil
    }

}

@objc(SBQueueStartScriptCommand) class QueueStartScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        QueueController.shared.start(self)
        return nil
    }

}

@objc(SBQueueStopScriptCommand) class QueueStopScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        QueueController.shared.stop(self)
        return nil
    }

}
