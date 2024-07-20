//
//  Utilities.swift
//  Subler
//
//  Created by Damiano Galassi on 31/01/2019.
//

import Cocoa

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
                case -1744://Int32(errAEEventWouldRequireUserConsent):
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


extension String {

    // All content is licensed under the terms of the MIT open source license.
    // Copyright (c) 2016 Matthijs Hollemans and contributors

    func minimumEditDistance(other: String) -> Int {
        let m = self.count
        let n = other.count
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        // initialize matrix
        for index in 1...m {
            // the distance of any first string to an empty second string
            matrix[index][0] = index
        }

        for index in 1...n {
            // the distance of any second string to an empty first string
            matrix[0][index] = index
        }

        // compute Levenshtein distance
        for (i, selfChar) in self.enumerated() {
            for (j, otherChar) in other.enumerated() {
                if otherChar == selfChar {
                    // substitution of equal symbols with cost 0
                    matrix[i + 1][j + 1] = matrix[i][j]
                } else {
                    // minimum of the cost of insertion, deletion, or substitution
                    // added to the already computed costs in the corresponding cells
                    matrix[i + 1][j + 1] = Swift.min(matrix[i][j] + 1, matrix[i + 1][j] + 1, matrix[i][j + 1] + 1)
                }
            }
        }
        return matrix[m][n]
    }
}
