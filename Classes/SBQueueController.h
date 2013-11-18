//
//  SBQueueController.h
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

@class SBQueueItem;
@class SBTableView;
@class MP42File;

typedef enum SBQueueStatus : NSUInteger {
    SBQueueStatusUnknown = 0,
    SBQueueStatusWorking,
    SBQueueStatusCompleted,
    SBQueueStatusFailed,
    SBQueueStatusCancelled,
} SBQueueStatus;

@interface SBQueueController : NSWindowController {
    IBOutlet NSButton *start;
    IBOutlet NSButton *open;

    IBOutlet NSTextField *countLabel;
    IBOutlet NSProgressIndicator *progressIndicator;

    IBOutlet NSButton *OptimizeOption;
    IBOutlet NSButton *MetadataOption;
    IBOutlet NSButton *ITunesGroupsOption;
    IBOutlet NSButton *AutoStartOption;
    IBOutlet NSBox    *optionsBox;
    BOOL optionsStatus;

    IBOutlet NSScrollView   *tableScrollView;
    IBOutlet SBTableView    *tableView;

    NSURL *destination;
    BOOL customDestination;
    IBOutlet NSPopUpButton *destButton;

    NSImage *docImg;

    dispatch_queue_t   queue;
    MP42File           *_currentMP4;

    NSMutableArray     *filesArray;
    SBQueueStatus      status;

    IOPMAssertionID _assertionID;
    BOOL            _cancelled;
}

@property(readonly) SBQueueStatus status;

+ (SBQueueController *)sharedManager;

- (void)start:(id)sender;
- (void)stop:(id)sender;

- (void)addItem:(SBQueueItem*)item;

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
