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

@property (class, readonly) SBQueueController *sharedManager;

@property (nonatomic, readonly) SBQueue *queue;

- (IBAction)open:(id)sender;

- (void)addItemsFromURLs:(NSArray<NSURL *> *)URLs atIndex:(NSInteger)index;
- (void)addItem:(SBQueueItem *)item;
- (void)editItem:(SBQueueItem *)item;

- (IBAction)start:(id)sender;
- (IBAction)stop:(id)sender;

@property (nonatomic, readonly) BOOL saveQueueToDisk;

@end

NS_ASSUME_NONNULL_END
