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

            // Mare sure the target is running, if not the consent alert will not be shown.
            NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleIdentifier, options: [],
                                                 additionalEventParamDescriptor: nil, launchIdentifier: nil)

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

func sendToFileExternalApp(fileURL: URL) -> Bool {
    let filePath = fileURL.path

    if #available(macOS 10.15, *) {
        if let script = NSAppleScript(source: """
            tell application "TV" to add (POSIX file "\(filePath)")
            """) {

            let result = automationConsent(bundleIdentifier: "com.apple.TV", promptIfNeeded: true)
            if result == .granted {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                return error != nil
            }
        }
    } else {
        if let script = NSAppleScript(source: """
            tell application "iTunes" to add (POSIX file "\(filePath)")
            """) {

            let result = automationConsent(bundleIdentifier: "com.apple.iTunes", promptIfNeeded: true)
            if result == .granted {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                return error != nil
            }
        }
    }
    
    return false
}
