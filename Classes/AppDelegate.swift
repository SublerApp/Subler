//
//  AppDelegate.swift
//  Subler
//
//  Created by Damiano Galassi on 16/02/2018.
//

import Cocoa
import MP42Foundation

final class DocumentController : NSDocumentController {

    private var openPanel: NSOpenPanel?

    override func openDocument(_ sender: Any?) {
        if let openPanel = self.openPanel {
            openPanel.makeKeyAndOrderFront(self)
        } else {
            super.openDocument(sender)
        }
    }

    override func beginOpenPanel(_ openPanel: NSOpenPanel, forTypes inTypes: [String]?, completionHandler: @escaping (Int) -> Void) {
        if self.openPanel == nil {
            self.openPanel = openPanel
        }
        super.beginOpenPanel(openPanel, forTypes: inTypes, completionHandler: { result in self.openPanel = nil; completionHandler(result) } )
    }

    private func dismissOpenPanel() {
        self.openPanel?.close()
        self.openPanel = nil
    }

    override func addDocument(_ document: NSDocument) {
        self.dismissOpenPanel()
        super.addDocument(document)
    }

    override func openDocument(withContentsOf url: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        let ext = url.pathExtension.lowercased()

        if ["mkv", "mka", "mks", "mov", "264", "h264"].contains(ext) {
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

    override func document(for url: URL) -> NSDocument? {
        return self.documents.first { $0.fileURL == url }
    }
}

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    @IBOutlet weak var sendToExternalApp: NSMenuItem!

    @MainActor private lazy var prefsController: PrefsWindowController = {
        return PrefsWindowController()
    }()

    private let logger = Logger.shared

    @MainActor private lazy var activityWindowController: ActivityWindowController = {
        return ActivityWindowController(logger: logger)
    }()

    @MainActor private lazy var documentController: DocumentController = {
        return DocumentController()
    }()

    @MainActor private func runDonateAlert() {
        let defaults = UserDefaults.standard
        let firstLaunch = defaults.bool(forKey: "SBFirstLaunch") ? false : true

        let donateNagTime = Double(60 * 60 * 24 * 7)
        let donateNagTimeLong = Double(60 * 60 * 24 * 180)

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

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        Prefs.register()
        MetadataPrefs.register()

        _ = documentController
        _ = activityWindowController

        logger.clear()
        MP42File.setGlobalLogger(logger)

        _ = QueueController.shared

        if Prefs.showQueueWindow {
            QueueController.shared.showWindow(self)
        }
        
        if #available(macOS 10.15, *) {
            sendToExternalApp.title = NSLocalizedString("Send to TV", comment: "Send to tv app menu item")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        //if Prefs.suppressDonationAlert == false {
        //    runDonateAlert()
        //}
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let state = QueueController.shared.status

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
        do {
            try PresetManager.shared.save()
            try QueueController.shared.saveToDisk()
        } catch {
            logger.write(toLog: "Failed to save queue to disk!")
        }
        Prefs.showQueueWindow = QueueController.shared.window?.isVisible ?? false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        if Prefs.showOpenPanelAtLaunch {
            documentController.openDocument(self)
        }
        return false
    }

    @IBAction func toggleStartStop(_ sender: Any?) {
        QueueController.shared.toggleStartStop(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action

        if action == #selector(toggleStartStop(_:)) {
            let state = QueueController.shared.status
            if state == .working {
                menuItem.title = NSLocalizedString("Stop Queue", comment: "Main Menu -> Stop Queue")
            } else {
                menuItem.title = NSLocalizedString("Start Queue", comment: "Main Menu -> Start Queue")
            }
        }

        return true
    }

    // MARK: actions

    @IBAction func openInQueue(_ sender: Any) {
        QueueController.shared.showWindow(self)
        QueueController.shared.open(sender)
    }

    @IBAction func showQueueWindow(_ sender: Any) {
        QueueController.shared.showWindow(self)
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
        guard let url = URL(string: "https://github.com/SublerApp/Subler/wiki") else { return }
        NSWorkspace.shared.open(url)
    }
}

extension AppDelegate {

    func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool {
        if key == "queueItems" {
            return true
        } else {
            return false
        }
    }

    @MainActor @objc(queueItems) func queueItems() -> [QueueItem] {
        let queue = QueueController.shared
        let indexes = IndexSet(integersIn: 0..<Int(queue.count))
        return queue.items(at: indexes)
    }

    @MainActor @objc(insertObject:inItemsAtIndex:) func insert(object: QueueItem, inItemsAtIndex index: UInt) {
        QueueController.shared.insert(items: [object], at: IndexSet(integer: IndexSet.Element(index)))
    }

    @MainActor @objc(removeObjectFromItemsAtIndex:) func removeObjectFromItemsAtIndex(_ index: UInt) {
        QueueController.shared.remove(at: IndexSet(integer: IndexSet.Element(index)))
    }

}
