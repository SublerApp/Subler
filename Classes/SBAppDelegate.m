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
#import "SBLogger.h"

#import <MP42Foundation/MP42File.h>

#define DONATE_NAG_TIME (60 * 60 * 24 * 7)

@implementation SBAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    documentController = [[SBDocumentController alloc] init];

    [SBPrefsController registerUserDefaults];

    NSString *appSupportPath = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                     NSUserDomainMask,
                                                                     YES) firstObject] stringByAppendingPathComponent:@"Subler"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:appSupportPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }

    NSString *path = [appSupportPath stringByAppendingPathComponent:@"debugLog.txt"];



    SBLogger *logger = [[SBLogger alloc] initWithLogFile:[NSURL fileURLWithPath:path]];
    [logger clearLog];

    debugLogController = [[SBLogWindowController alloc] initWithLogger:logger];
    [MP42File setGlobalLogger:logger];

    [logger release];

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBShowQueueWindow"]) {
        [[SBQueueController sharedManager] showWindow:self];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager savePresets];
    
    if ([[[SBQueueController sharedManager] window] isVisible]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBShowQueueWindow"];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"SBShowQueueWindow"];
    }

    if (![[SBQueueController sharedManager] saveQueueToDisk]) {
        if ([[NSUserDefaults standardUserDefaults] valueForKey:@"Debug"]) {
            NSLog(@"Failed to save queue to disk!");
        }
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app
{
    SBQueueStatus status= [[SBQueueController sharedManager] status];
    NSInteger result;
    if (status == SBQueueStatusWorking) {
        result = NSRunCriticalAlertPanel(
                                         NSLocalizedString(@"Are you sure you want to quit Subler?", nil),
                                         NSLocalizedString(@"Your current queue will be lost. Do you want to quit anyway?", nil),
                                         NSLocalizedString(@"Quit", nil), NSLocalizedString(@"Don't Quit", nil), nil);
        
        if (result == NSAlertDefaultReturn) {
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
#ifdef DONATION
    BOOL firstLaunch = YES;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FirstLaunch"]) {
        firstLaunch = NO;
    }

    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"WarningDonate"]) {
        NSDate *lastDonateDate = [[NSUserDefaults standardUserDefaults] valueForKey:@"DonateAskDate"];
        const BOOL timePassed = !lastDonateDate || (-1 * [lastDonateDate timeIntervalSinceNow]) >= DONATE_NAG_TIME;

        if (!firstLaunch && timePassed) {
            [[NSUserDefaults standardUserDefaults] setValue:[NSDate date] forKey:@"DonateAskDate"];

            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText: NSLocalizedString(@"Support Subler", "Donation -> title")];

            NSString *donateMessage = [NSString stringWithFormat: @"%@",
                                        NSLocalizedString(@" A lot of time and effort have gone into development, coding, and refinement."
                                                          " If you enjoy using it, please consider showing your appreciation with a donation.", "Donation -> message")];

            [alert setInformativeText:donateMessage];
            [alert setAlertStyle: NSInformationalAlertStyle];

            [alert addButtonWithTitle: NSLocalizedString(@"Donate", "Donation -> button")];
            NSButton * noDonateButton = [alert addButtonWithTitle: NSLocalizedString(@"Nope", "Donation -> button")];
            [noDonateButton setKeyEquivalent:@"\e"]; //escape key

            const BOOL allowNeverAgain = lastDonateDate != nil; //hide the "don't show again" check the first time - give them time to try the app
            [alert setShowsSuppressionButton:allowNeverAgain];
            if (allowNeverAgain) {
                [[alert suppressionButton] setTitle:NSLocalizedString(@"Don't ask me about this ever again.", "Donation -> button")];
            }

            const NSInteger donateResult = [alert runModal];
            if (donateResult == NSAlertFirstButtonReturn) {
                [self linkDonate:self];
            }

            if (allowNeverAgain) {
                [[NSUserDefaults standardUserDefaults] setBool:([[alert suppressionButton] state] != NSOnState) forKey:@"WarningDonate"];
            }

            [alert release];
        }
    }

    if (firstLaunch) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FirstLaunch"];
    }
#endif
    
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
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
                                             URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=YKZHVC6HG6AFQ&lc=GB&item_name=Subler&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHosted"]];
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
    if ([extension caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"mka"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"mks"] == NSOrderedSame ||
        [extension caseInsensitiveCompare: @"mov"] == NSOrderedSame) {

        CFRetain(completionHandler);

        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *outError = nil;

            SBDocument *doc = [[self openUntitledDocumentAndDisplay:displayDocument error:&outError] retain];
            completionHandler(doc, NO, outError);
            if (doc) {
                [doc showImportSheet:@[url]];
            }
            CFRelease(completionHandler);
            [doc release];
        });
    }
    else {
        [super openDocumentWithContentsOfURL:url display:displayDocument completionHandler:completionHandler];
    }
}

- (nullable __kindof NSDocument *)documentForURL:(NSURL *)url
{
    NSArray<__kindof NSDocument *> *documents = nil;
    @synchronized(self) {
        documents = [[self.documents copy] autorelease];
    }

    for (NSDocument *doc in documents) {
        if ([doc.fileURL isEqualTo:url.filePathURL]) {
            return doc;
        }
    }

    return nil;
}

@end
