//
//  SBAppDelegate.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBAppDelegate.h"
#import "SBDocument.h"
#import "SBPresetManager.h"
#import "SBQueueController.h"
#import "SBPrefsController.h"
#import "SBLogWindowController.h"
#import "SBMetadataHelper.h"
#import "SBLogger.h"

#import <MP42Foundation/MP42File.h>

#define DONATE_NAG_TIME (60 * 60 * 24 * 7)
#define DONATE_NAG_TIME_LONG (60 * 60 * 24 * 120)

@interface SBAppDelegate ()
{
    SBPrefsController *prefController;
    SBLogWindowController *debugLogController;
    SBDocumentController *documentController;
}
@end

@implementation SBAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    documentController = [[SBDocumentController alloc] init];

    [SBPrefsController registerUserDefaults];

    NSString *appSupportPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                     NSUserDomainMask,
                                                                     YES).firstObject stringByAppendingPathComponent:@"Subler"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:appSupportPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }

    NSString *path = [appSupportPath stringByAppendingPathComponent:@"debugLog.txt"];

    SBLogger *logger = [[SBLogger alloc] initWithLogFile:[NSURL fileURLWithPath:path]];
    [logger clearLog];

    debugLogController = [[SBLogWindowController alloc] initWithLogger:logger];
    MP42File.globalLogger = logger;
    
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"SBAdditionalDebugInfo"]) {
        // TODO
        //SBMetadataHelper.logger = logger;
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SBShowQueueWindow"]) {
        [[SBQueueController sharedManager] showWindow:self];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager savePresets];
    
    if ([SBQueueController sharedManager].window.visible) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"SBShowQueueWindow"];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"SBShowQueueWindow"];
    }

    if (![[SBQueueController sharedManager] saveQueueToDisk]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"Debug"]) {
            NSLog(@"Failed to save queue to disk!");
        }
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app
{
    SBQueueStatus status= SBQueueController.sharedManager.queue.status;

    if (status == SBQueueStatusWorking) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Are you sure you want to quit Subler?", @"Quit alert title.");
        alert.informativeText = NSLocalizedString(@"Your current queue will be lost. Do you want to quit anyway?", @"Quit alert description.");
        [alert addButtonWithTitle:NSLocalizedString(@"Quit", @"Quit alert default action.")];
        [alert addButtonWithTitle:NSLocalizedString(@"Don't Quit", @"Quit alert cancel action.")];
        alert.alertStyle = NSAlertStyleCritical;

        NSInteger result = [alert runModal];

        if (result == NSAlertFirstButtonReturn) {
            return NSTerminateNow;
        }
        else {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    BOOL firstLaunch = YES;

    if ([NSUserDefaults.standardUserDefaults boolForKey:@"SBFirstLaunch"]) {
        firstLaunch = NO;
    }

    NSString *currentVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    NSString *lastVersion = [NSUserDefaults.standardUserDefaults objectForKey:@"SBDonateAskVersion"];
    const BOOL versionChanged = currentVersion != nil && ![currentVersion isEqualTo:lastVersion];

    if (versionChanged) {
        [NSUserDefaults.standardUserDefaults setObject:currentVersion forKey:@"SBDonateAskVersion"];

        NSDate *lastDonateDate = [NSUserDefaults.standardUserDefaults objectForKey:@"SBDonateAskDate"];
        const BOOL timePassed = !lastDonateDate || (-1 * lastDonateDate.timeIntervalSinceNow) >= DONATE_NAG_TIME_LONG;

        if (timePassed) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SBWarningDonate"];
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SBFirstLaunch"];
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SBDonateAskDate"];
        }
    }

    if (![NSUserDefaults.standardUserDefaults boolForKey:@"SBWarningDonate"]) {
        NSDate *lastDonateDate = [NSUserDefaults.standardUserDefaults objectForKey:@"SBDonateAskDate"];
        const BOOL timePassed = !lastDonateDate || (-1 * lastDonateDate.timeIntervalSinceNow) >= DONATE_NAG_TIME;

        if (!firstLaunch && timePassed) {
            [NSUserDefaults.standardUserDefaults setObject:[NSDate date] forKey:@"SBDonateAskDate"];

            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NSLocalizedString(@"Support Subler", "Donation -> title");

            NSString *donateMessage = [NSString stringWithFormat: @"%@",
                                        NSLocalizedString(@" A lot of time and effort have gone into development, coding, and refinement."
                                                          " If you enjoy using it, please consider showing your appreciation with a donation.", "Donation -> message")];

            alert.informativeText = donateMessage;
            alert.alertStyle = NSAlertStyleInformational;

            [alert addButtonWithTitle: NSLocalizedString(@"Donate", "Donation -> button")];
            NSButton *noDonateButton = [alert addButtonWithTitle: NSLocalizedString(@"Nope", "Donation -> button")];
            noDonateButton.keyEquivalent = [NSString stringWithFormat:@"%c", 0x1B]; //escape key

            const BOOL allowAgain = lastDonateDate != nil; //hide the "don't show again" check the first time - give them time to try the app
            alert.showsSuppressionButton = allowAgain;
            if (allowAgain) {
                alert.suppressionButton.title = NSLocalizedString(@"Don't ask me about this again for this version.", "Donation -> button");
            }

            const NSInteger donateResult = [alert runModal];
            if (donateResult == NSAlertFirstButtonReturn) {
                [self linkDonate:self];
            }

            if (allowAgain) {
                [NSUserDefaults.standardUserDefaults setBool:(alert.suppressionButton.state != NSOnState) forKey:@"SBWarningDonate"];
            }
        }
    }

    if (firstLaunch) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"SBFirstLaunch"];
    }

    [SBQueueController sharedManager];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

- (IBAction)openInQueue:(id)sender
{
    [[SBQueueController sharedManager] showWindow:self];
    [[SBQueueController sharedManager] open:sender];
}

- (IBAction) showBatchWindow: (id) sender
{
    [[SBQueueController sharedManager] showWindow:self];
}

- (IBAction) showPrefsWindow: (id) sender
{
    if (!prefController) {
        prefController = [[SBPrefsController alloc] init];
    }
    [prefController showWindow:self];
}

- (IBAction) showDebugLog:(id)sender
{
    [debugLogController showWindow:self];
}

- (IBAction) donate:(id)sender
{
    [self linkDonate:sender];
}

- (IBAction) help:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://bitbucket.org/galad87/subler/wiki/Home"]];
}

- (IBAction) linkDonate:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://subler.org/donate.php"]];
}

@end

@implementation SBAppDelegate (QueueScripting)

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
    if ([key isEqualToString:@"items"]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSArray<SBQueueItem *> *)items
{
    SBQueue *queue = SBQueueController.sharedManager.queue;

    NSMutableArray<SBQueueItem *> *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < queue.count; i++) {
        [items addObject:[queue itemAtIndex:i]];
    }
    return items;
}

- (void)insertObject:(SBQueueItem *)object inItemsAtIndex:(NSUInteger)index
{

    [SBQueueController.sharedManager.queue insertItem:object atIndex:index];
}

- (void)removeObjectFromItemsAtIndex:(NSUInteger)index
{

    [SBQueueController.sharedManager.queue removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:index]];
}

@end

@implementation SBDocumentController

- (void)openDocumentWithContentsOfURL:(NSURL * _Nonnull)url
                              display:(BOOL)displayDocument
                    completionHandler:(void (^ _Nonnull)(NSDocument * _Nullable document,
                                                         BOOL documentWasAlreadyOpen,
                                                         NSError * _Nullable error))completionHandler
{
    NSString *extension = url.pathExtension;
    MP42File *mp4 = nil;

    if ([extension caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"m4v"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"m4a"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"m4r"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"m4b"] == NSOrderedSame) {

        mp4 = [[MP42File alloc] initWithURL:url error:NULL];
    }

    if ([extension caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"mka"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"mks"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"mov"] == NSOrderedSame ||
        mp4 == nil) {

        NSError *outError = nil;

        SBDocument *doc = [self openUntitledDocumentAndDisplay:displayDocument error:&outError];
        completionHandler(doc, NO, outError);
        if (doc) {
            [doc showImportSheet:@[url]];
        }
    }
    else {
        [super openDocumentWithContentsOfURL:url display:displayDocument completionHandler:completionHandler];
    }

}

- (nullable __kindof NSDocument *)documentForURL:(NSURL *)url
{
    NSArray<__kindof NSDocument *> *documents = nil;
    @synchronized(self) {
        documents = [self.documents copy];
    }

    for (NSDocument *doc in documents) {
        if ([doc.fileURL isEqualTo:url.filePathURL]) {
            return doc;
        }
    }

    return nil;
}

@end
