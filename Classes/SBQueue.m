//
//  SBQueue.m
//  Subler
//
//  Created by Damiano Galassi on 27/02/14.
//
//

#import "SBQueue.h"
#import <IOKit/pwr_mgt/IOPMLib.h>

NSString *SBQueueWorkingNotification = @"SBQueueWorkingNotification";
NSString *SBQueueCompletedNotification = @"SBQueueCompletedNotification";
NSString *SBQueueFailedNotification = @"SBQueueFailedNotification";
NSString *SBQueueCancelledNotification = @"SBQueueCancelledNotification";

@interface SBQueue ()

@property (atomic) SBQueueStatus status;

@property (nonatomic, copy) NSURL *URL;
@property (nonatomic) NSMutableArray *items;

@property (nonatomic) NSUInteger currentIndex;
@property (atomic) SBQueueItem *currentItem;
@property (atomic) BOOL cancelled;

@property (nonatomic) IOPMAssertionID assertionID;
@property (nonatomic) IOReturn        io_success;

@property (nonatomic) dispatch_queue_t workQueue;
@property (nonatomic) dispatch_queue_t saveQueue;

@end

@implementation SBQueue

- (instancetype)initWithURL:(NSURL *)queueURL {
    self = [super init];
    if (self) {
        _workQueue = dispatch_queue_create("org.subler.WorkQueue", NULL);
        _saveQueue = dispatch_queue_create("org.subler.SaveQueue", NULL);
        _URL = [queueURL copy];

        if ([[NSFileManager defaultManager] fileExistsAtPath:queueURL.path]) {
            @try {
                _items = [NSKeyedUnarchiver unarchiveObjectWithFile:queueURL.path];
            }
            @catch (NSException *exception) {
                [[NSFileManager defaultManager] removeItemAtURL:queueURL error:nil];
                _items = nil;
            }

            for (SBQueueItem *item in _items)
                if (item.status == SBQueueItemStatusWorking)
                    item.status = SBQueueItemStatusFailed;

        }

        if (!_items) {
            _items = [[NSMutableArray alloc] init];
        }

    }
    return self;
}

- (BOOL)saveQueueToDisk {
    __block BOOL result;
    dispatch_sync(self.saveQueue, ^{
        result = [NSKeyedArchiver archiveRootObject:self.items toFile:self.URL.path];
    });
    return result;
}

- (SBQueueItem *)firstItemInQueue {
    __block SBQueueItem *firstItem = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        for (SBQueueItem *item in self.items) {
            if ((item.status != SBQueueItemStatusCompleted) && (item.status != SBQueueItemStatusFailed)) {
                firstItem = item;
                firstItem.status = SBQueueItemStatusWorking;
                break;
            }
        }
    });
    return firstItem;
}

- (NSUInteger)indexOfCurrentItem {
    __block NSUInteger index;
    dispatch_sync(dispatch_get_main_queue(), ^{
        index = [self.items indexOfObject:self.currentItem];
    });
    return index;
}

#pragma mark - item management

- (void)addItem:(SBQueueItem *)item {
    [self.items addObject:item];
}

- (NSUInteger)count {
    return self.items.count;
}

- (NSUInteger)readyCount {
    NSUInteger count = 0;
    for (SBQueueItem *item in self.items)
        if (item.status == SBQueueItemStatusReady)
            count++;
    return count;
}

- (SBQueueItem *)itemAtIndex:(NSUInteger)index {
    return (self.items)[index];
}

- (NSArray *)itemsAtIndexes:(NSIndexSet *)indexes {
    return [self.items objectsAtIndexes:indexes];
}

- (NSUInteger)indexOfItem:(SBQueueItem *)item {
    return [self.items indexOfObject:item];
}

- (NSIndexSet *)indexesOfItemsWithStatus:(SBQueueItemStatus)status {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    [self.items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (((SBQueueItem *)obj).status == status) {
            [indexes addIndex:idx];
        }
    }];
    return indexes;
}

- (void)insertItem:(SBQueueItem *)anItem atIndex:(NSUInteger)index {
    [self.items insertObject:anItem atIndex:index];
}

- (void)removeItemsAtIndexes:(NSIndexSet *)indexes {
    [self.items removeObjectsAtIndexes:indexes];
}

- (void)removeItem:(SBQueueItem *)item {
    [self.items removeObject:item];
}

- (NSIndexSet *)removeCompletedItems {
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];

    for (SBQueueItem *item in self.items)
        if (item.status == SBQueueItemStatusCompleted)
            [indexes addIndex:[self.items indexOfObject:item]];

    [self.items removeObjectsAtIndexes:indexes];

    return indexes;
}

#pragma mark - Queue control

- (void)disableSleep {
    CFStringRef reasonForActivity= CFSTR("Subler Queue Started");
    _io_success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep,
                                                      kIOPMAssertionLevelOn, reasonForActivity, &_assertionID);
}

- (void)enableSleep {
    if (_io_success == kIOReturnSuccess) {
        IOPMAssertionRelease(_assertionID);
    }
}

/*
 * Starts the queue.
 */
- (void)start {
    if (self.status == SBQueueStatusWorking) {
        return;
    } else {
        self.status = SBQueueStatusWorking;
    }

    // Enable sleep assertion
    [self disableSleep];

    dispatch_async(self.workQueue, ^{

        NSUInteger completedCount = 0;
        NSUInteger failedCount = 0;

        for (;;) {
            @autoreleasepool {
                NSError *outError = nil;
                BOOL noErr = NO;

                // Save the queue
                [self saveQueueToDisk];

                // Get the first item available in the queue
                self.currentItem = [self firstItemInQueue];

                if (!self.currentItem) {
                    break;
                }

                self.currentIndex = [self indexOfCurrentItem];
                self.currentItem.status = SBQueueItemStatusWorking;
                self.currentItem.delegate = self;

                [self handleSBStatusWorking:0 index:self.currentIndex];
                noErr = [self.currentItem processWithOptions:self.optimize error:&outError];

                // Check results
                if (self.cancelled) {
                    if (outError.code != 12) {
                        self.currentItem.status = SBQueueItemStatusCancelled;
                    }
                    self.currentItem = nil;
                    [self handleSBStatusCancelled];
                    break;
                }

                if (noErr) {
                    self.currentItem.status = SBQueueItemStatusCompleted;
                    completedCount += 1;
                }
                else {
                    self.currentItem.status = SBQueueItemStatusFailed;
                    failedCount += 1;
                    [self handleSBStatusFailed:outError];
                }

                self.currentItem.delegate = nil;
                self.currentItem = nil;
            }

            if (self.status == SBQueueStatusCancelled) {
                break;
            }
        }

        // Save to disk
        [self saveQueueToDisk];

        // Disable sleep assertion
        [self enableSleep];
        [self handleSBStatusCompleted:completedCount failed:failedCount];

        // Reset cancelled state
        self.cancelled = NO;
    });
}

/**
 * Stops the queue and abort the current work.
 */
- (void)stop {
    self.cancelled = YES;
    [self.currentItem cancel];
}

- (void)progressStatus:(double)progress {
    [self handleSBStatusWorking:progress index:-1];
}

/**
 * Processes SBQueueStatusWorking state information. Current implementation just
 * sends SBQueueWorkingNotification.
 */
- (void)handleSBStatusWorking:(CGFloat)progress index:(NSInteger)index {
    NSString *description = self.currentItem.localizedWorkingDescription;
    if (!description) {
        description = NSLocalizedString(@"Working", @"Queue Working.");
    }
    NSString *info = [NSString stringWithFormat:@"%@, item %ld of %lu.", description, (long)self.currentIndex + 1, (unsigned long)self.items.count];

    [[NSNotificationCenter defaultCenter] postNotificationName:SBQueueWorkingNotification object:self userInfo:@{@"ProgressString": info,
                                                                                                                 @"Progress": @(progress),
                                                                                                                 @"ItemIndex": @(index)}];
}

/**
 * Processes SBQueueStatusCompleted state information. Current implementation just
 * sends SBQueueCompletedNotification.
 */
- (void)handleSBStatusCompleted:(NSUInteger)completedCount failed:(NSUInteger)failedCount {
    self.status = SBQueueStatusCompleted;
    [[NSNotificationCenter defaultCenter] postNotificationName:SBQueueCompletedNotification object:self userInfo:@{@"CompletedCount": @(completedCount),
                                                                                                                   @"FailedCount": @(failedCount)}];
}

/**
 * Processes SBQueueStatusFailed state information. Current implementation just
 * sends SBQueueFailedNotification.
 */
- (void)handleSBStatusFailed:(NSError *)error {
    self.status = SBQueueStatusFailed;
    [[NSNotificationCenter defaultCenter] postNotificationName:SBQueueFailedNotification object:self userInfo:@{@"Error" : error != nil ? error : [NSNull null]}];
}

/**
 * Processes SBQueueStatusCancelled state information. Current implementation just
 * sends SBQueueCancelledNotification.
 */
- (void)handleSBStatusCancelled {
    self.status = SBQueueStatusCancelled;
    [[NSNotificationCenter defaultCenter] postNotificationName:SBQueueCancelledNotification object:self];
}

@end
