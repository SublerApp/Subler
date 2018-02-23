//
//  AppDelegate.swift
//  Subler
//
//  Created by Damiano Galassi on 16/02/2018.
//

import Cocoa

class DocumentController : NSDocumentController {
    override func openDocument(withContentsOf url: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        let ext = url.pathExtension.lowercased()

        if ["mkv", "mka", "mks", "mov"].contains(ext) {
            do {
                let doc = try self.openUntitledDocumentAndDisplay(displayDocument)
                completionHandler(doc, false, nil)
                if let windowController = doc.windowControllers.first as? DocumentWindowController {
                    windowController.showImportSheet(fileURLs: [url])
                }
            } catch {
                completionHandler(nil, false, error)
            }
        }
        else {
            super.openDocument(withContentsOf: url, display: displayDocument, completionHandler: completionHandler)
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private static func appSupportURL() -> URL {
        let fileManager = FileManager.default
        if let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Subler") {

            do {
                if fileManager.fileExists(atPath: url.path) == false {
                    try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
                }
            }
            catch _ {
                fatalError("Couldn't create the app support directory")
            }

            return url
        }
        else {
            fatalError("Couldn't find the app support directory")
        }
    }

    private lazy var prefsController: PrefsWindowController = {
        return PrefsWindowController()
    }()

    private lazy var logger: Logger = {
        return Logger(fileURL: AppDelegate.appSupportURL().appendingPathComponent("debugLog.txt"))
    }()

    private lazy var activityWindowController: ActivityWindowController = {
        return ActivityWindowController(logger: logger)
    }()

    private lazy var documentController: DocumentController = {
        return DocumentController()
    }()

    private func runDonateAlert() {
        let defaults = UserDefaults.standard
        let firstLaunch = defaults.bool(forKey: "SBFirstLaunch") ? false : true

        let donateNagTime = Double(60 * 60 * 24 * 7)
        let donateNagTimeLong = Double(60 * 60 * 24 * 120)

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = defaults.string(forKey: "SBDonateAskVersion") ?? ""

        let versionChanged = currentVersion != lastVersion

        if versionChanged {
            defaults.set(currentVersion, forKey: "SBDonateAskVersion")

            let lastDonateDate = defaults.object(forKey: "SBDonateAskDate") as? Date
            let timePassed = lastDonateDate == nil || (-1 * (lastDonateDate?.timeIntervalSinceNow ?? 0)) >= donateNagTimeLong

            if timePassed {
                defaults.removeObject(forKey: "SBWarningDonate")
                defaults.removeObject(forKey: "SBFirstLaunch")
                defaults.removeObject(forKey: "SBDonateAskDate")
            }
        }

        if defaults.bool(forKey: "SBWarningDonate") == false {
            let lastDonateDate = defaults.object(forKey: "SBDonateAskDate") as? Date
            let timePassed = lastDonateDate == nil || (-1 * (lastDonateDate?.timeIntervalSinceNow ?? 0)) >= donateNagTime

            if firstLaunch == false && timePassed {
                defaults.set(Date(), forKey: "SBDonateAskDate")

                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Support Subler", comment: "Donation -> title")
                alert.informativeText = NSLocalizedString(" A lot of time and effort have gone into development, coding, and refinement.\n If you enjoy using it, please consider showing your appreciation with a donation.", comment: "Donation -> message")
                alert.alertStyle = .informational

                alert.addButton(withTitle: NSLocalizedString("Donate", comment: "Donation -> button"))
                let noDonateButton = alert.addButton(withTitle: NSLocalizedString("Nope", comment: "Donation -> button"))
                noDonateButton.keyEquivalent = String(format: "%c", 0x1b) // escape key

                let allowAgain = lastDonateDate != nil //hide the "don't show again" check the first time - give them time to try the app
                alert.showsSuppressionButton = allowAgain

                if allowAgain {
                    alert.suppressionButton?.title = NSLocalizedString("Don't ask me about this again for this version.", comment: "Donation -> button")
                }

                let donateResult = alert.runModal()

                if donateResult == .alertFirstButtonReturn {
                    donate(self)
                }

                if allowAgain {
                    defaults.set(alert.suppressionButton?.state != .on, forKey: "SBWarningDonate")
                }
            }
        }

        if firstLaunch {
            defaults.set(true, forKey: "SBFirstLaunch")
        }
    }

    // MARK: delegates

    func applicationWillFinishLaunching(_ notification: Notification) {
        PrefsWindowController.registerUserDefaults()

        _ = documentController

        logger.clear()
        MP42File.setGlobalLogger(logger)

        _ = SBQueueController.sharedManager

        if UserDefaults.standard.bool(forKey: "SBShowQueueWindow") {
            SBQueueController.sharedManager.showWindow(self)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "SBIgnoreDonationAlert") == false {
            runDonateAlert()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let state = SBQueueController.sharedManager.queue.status

        if state == .working {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Are you sure you want to quit Subler?", comment: "Quit alert title.")
            alert.informativeText = NSLocalizedString("Your current queue will be lost. Do you want to quit anyway?", comment: "Quit alert description.")
            alert.addButton(withTitle: NSLocalizedString("Quit", comment: "Quit alert default action."))
            alert.addButton(withTitle: NSLocalizedString("Don't Quit", comment: "Quit alert cancel action."))
            alert.alertStyle = .critical

            let result = alert.runModal()
            return result == .alertFirstButtonReturn ? .terminateNow : .terminateCancel

        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        try! PresetManager.shared.save()
        if SBQueueController.sharedManager.saveQueueToDisk == false {
            logger.write(toLog: "Failed to save queue to disk!")
        }
        UserDefaults.standard.set(SBQueueController.sharedManager.window?.isVisible, forKey: "SBShowQueueWindow")
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: actions

    @IBAction func openInQueue(_ sender: Any) {
        SBQueueController.sharedManager.showWindow(self)
        SBQueueController.sharedManager.open(sender)
    }

    @IBAction func showBatchWindow(_ sender: Any) {
        SBQueueController.sharedManager.showWindow(self)
    }

    @IBAction func showPrefsWindow(_ sender: Any) {
        prefsController.showWindow(self)
    }

    @IBAction func showDebugLog(_ sender: Any) {
        activityWindowController.showWindow(self)
    }

    @IBAction func donate(_ sender: Any) {
        guard let url = URL(string: "https://subler.org/donate.php") else { return }
        NSWorkspace.shared.open(url)
    }

    @IBAction func help(_ sender: Any) {
        guard let url = URL(string: "https://bitbucket.org/galad87/subler/wiki/Home") else { return }
        NSWorkspace.shared.open(url)
    }
}

extension AppDelegate {

    override func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool {
        if key == "items" {
            return true
        } else {
            return false
        }
    }

    @objc(items) func items() -> [SBQueueItem] {
        let queue = SBQueueController.sharedManager.queue
        let indexes = IndexSet(integersIn: 0..<Int(queue.count))
        return queue.items(at: indexes)
    }

    @objc(insertObject:inItemsAtIndex:) func insert(object: SBQueueItem, inItemsAtIndex index: UInt) {
        SBQueueController.sharedManager.queue.insert(object, at: index)
    }

    @objc(removeObjectFromItemsAtIndex:) func removeObjectFromItemsAtIndex(_ index: UInt) {
        SBQueueController.sharedManager.queue.removeItems(at: IndexSet(integer: IndexSet.Element(index)))
    }

}
