//
//  SBQueueController.h
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SBQueue.h"

NS_ASSUME_NONNULL_BEGIN

@class SBQueueItem;
@class SBOptionsViewController;
@class SBQueuePreferences;

@class SBTableView;
@class MP42File;

@interface SBQueueController : NSWindowController {
@private
    IBOutlet NSTextField *_countLabel;
    IBOutlet NSProgressIndicator *_progressIndicator;

    IBOutlet SBTableView *_tableView;

    IBOutlet NSWindow *_detachedWindow;
    IBOutlet NSToolbarItem *_startItem;

    NSPopover *_popover;
    NSPopover *_itemPopover;
    SBOptionsViewController *_windowController;

    SBQueuePreferences *_prefs;
    NSMutableDictionary<NSString *, id> *_options;

    NSImage *_docImg;

    SBQueue *_queue;
}

@property(readonly) SBQueueStatus status;

+ (SBQueueController *)sharedManager;

- (IBAction)open:(id)sender;

- (void)addItem:(SBQueueItem *)item;
- (void)editItem:(SBQueueItem *)item;

- (BOOL)saveQueueToDisk;

@end

NS_ASSUME_NONNULL_END
