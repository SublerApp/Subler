//
//  SBQueueController.h
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SBQueue.h"

@class SBQueueItem;
@class SBTableView;
@class MP42File;

@interface SBQueueController : NSWindowController {
    IBOutlet NSButton *_start;
    IBOutlet NSButton *_open;

    IBOutlet NSTextField *_countLabel;
    IBOutlet NSProgressIndicator *_progressIndicator;

    IBOutlet NSScrollView   *_tableScrollView;
    IBOutlet SBTableView    *_tableView;

    IBOutlet NSWindow *_detachedWindow;
    NSPopover *_popover;

    NSMutableDictionary *_options;
    NSImage *_docImg;

    SBQueue *_queue;
}

@property(readonly) SBQueueStatus status;

+ (SBQueueController *)sharedManager;

- (void)addItem:(SBQueueItem *)item;

- (BOOL)saveQueueToDisk;

- (IBAction)removeSelectedItems:(id)sender;
- (IBAction)removeCompletedItems:(id)sender;

- (IBAction)edit:(id)sender;
- (IBAction)showInFinder:(id)sender;

- (IBAction)toggleStartStop:(id)sender;
- (IBAction)toggleOptions:(id)sender;

- (IBAction)open:(id)sender;

@end
