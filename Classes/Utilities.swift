//
//  Utilities.swift
//  Subler
//
//  Created by Damiano Galassi on 31/01/2019.
//

import Cocoa

extension NSPasteboard.PasteboardType {
    static let backwardsCompatibleFileURL: NSPasteboard.PasteboardType = {
        if #available(OSX 10.13, *) {
            return NSPasteboard.PasteboardType.fileURL
        } else {
            return NSPasteboard.PasteboardType(kUTTypeFileURL as String)
        }
    } ()
}

enum PrivacyConsentState {
    case unknown
    case granted
    case denied
}

func automationConsent(bundleIdentifier: String, promptIfNeeded: Bool) -> PrivacyConsentState {
    var result: PrivacyConsentState = .denied
    if #available(macOS 10.14, *) {
        bundleIdentifier.withCString { (identifier) in
            var addressDesc = AEAddressDesc()
            let createDescResult = AECreateDesc(typeApplicationBundleID, identifier, strlen(identifier), &addressDesc)
            if createDescResult == noErr {
                let appleScriptPermission = AEDeterminePermissionToAutomateTarget(&addressDesc, typeWildCard, typeWildCard, promptIfNeeded)
                AEDisposeDesc(&addressDesc)
                switch appleScriptPermission {
                case -1744: //errAEEventWouldRequireUserConsent:
                    result = .unknown
                case noErr:
                    result = .granted
                case Int32(errAEEventNotPermitted):
                    result = .denied
                case Int32(procNotFound):
                    result = .unknown
                default:
                    result = .unknown
                    break
                }
            }
        }
        return result
    } else {
        return .granted
    }
}
