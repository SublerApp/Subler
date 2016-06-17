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

@interface SBQueueController : NSWindowController

@property(readonly) SBQueueStatus status;

+ (SBQueueController *)sharedManager;

- (IBAction)open:(id)sender;

- (void)addItem:(SBQueueItem *)item;
- (void)editItem:(SBQueueItem *)item;

@property (nonatomic, readonly) BOOL saveQueueToDisk;

@end

NS_ASSUME_NONNULL_END
