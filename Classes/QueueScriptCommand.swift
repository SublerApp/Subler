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
        SBQueueController.sharedManager.addItems(from: args, at: 0)
        return nil
    }

}

@objc(SBQueueStartScriptCommand) class QueueStartScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        SBQueueController.sharedManager.start(self)
        self.suspendExecution()
        return nil
    }

}

@objc(SBQueueStopScriptCommand) class QueueStopScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        SBQueueController.sharedManager.stop(self)
        return nil
    }

}
