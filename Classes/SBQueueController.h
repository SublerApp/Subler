//
//  SBQueueController.h
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

#import "SBQueue.h"

@class SBQueueItem;
@class SBTableView;
@class MP42File;

@interface SBQueueController : NSWindowController {
    IBOutlet NSButton *_start;
    IBOutlet NSButton *_open;

    IBOutlet NSTextField *_countLabel;
    IBOutlet NSProgressIndicator *_progressIndicator;

    IBOutlet NSButton *_optimizeOption;
    IBOutlet NSButton *_metadataOption;
    IBOutlet NSButton *_organizeGroupsOption;
    IBOutlet NSButton *_autoStartOption;
    IBOutlet NSBox    *_optionsBox;
    BOOL _optionsStatus;

    IBOutlet NSScrollView   *_tableScrollView;
    IBOutlet SBTableView    *_tableView;

    IBOutlet NSPopUpButton *_destButton;

    NSImage *_docImg;

    NSURL *_destination;
    BOOL _customDestination;

    SBQueue *_queue;
}

@property(readonly) SBQueueStatus status;

+ (SBQueueController *)sharedManager;

- (void)start:(id)sender;
- (void)stop:(id)sender;

- (void)addItem:(SBQueueItem *)item;

- (BOOL)saveQueueToDisk;

- (IBAction)removeSelectedItems:(id)sender;
- (IBAction)removeCompletedItems:(id)sender;

- (IBAction)edit:(id)sender;
- (IBAction)showInFinder:(id)sender;

- (IBAction)toggleStartStop:(id)sender;
- (IBAction)toggleOptions:(id)sender;

- (IBAction)open:(id)sender;
- (IBAction)chooseDestination:(id)sender;
- (IBAction)destination:(id)sender;

@end
