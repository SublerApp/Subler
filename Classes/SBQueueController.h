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
@private
    IBOutlet NSTextField *_countLabel;
    IBOutlet NSProgressIndicator *_progressIndicator;

    IBOutlet SBTableView    *_tableView;

    IBOutlet NSWindow *_detachedWindow;
    IBOutlet NSToolbarItem *_startItem;

    NSPopover *_popover;
    NSPopover *_itemPopover;

    NSMutableDictionary *_options;
    NSImage *_docImg;

    SBQueue *_queue;
}

@property(readonly) SBQueueStatus status;

+ (SBQueueController *)sharedManager;

- (void)addItem:(SBQueueItem *)item;
- (void)editItem:(SBQueueItem *)item;

- (BOOL)saveQueueToDisk;

@end
