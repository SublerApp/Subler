//
//  SBQueue.m
//  Subler
//
//  Created by Damiano Galassi on 27/02/14.
//
//

#import "SBQueue.h"

NSString *SBQueueWorkingNotification = @"SBQueueWorkingNotification";
NSString *SBQueueCompletedNotification = @"SBQueueCompletedNotification";
NSString *SBQueueFailedNotification = @"SBQueueFailedNotification";
NSString *SBQueueCancelledNotification = @"SBQueueCancelledNotification";

@interface SBQueue ()

@property (atomic) SBQueueStatus status;

@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, retain) NSMutableArray *items;

@property (atomic, retain) SBQueueItem *currentItem;
@property (atomic) NSUInteger currentIndex;
@property (atomic) BOOL cancelled;

@property (nonatomic) dispatch_queue_t workQueue;

@end

@implementation SBQueue

@synthesize status = _status;
@synthesize optimize = _optimize;
@synthesize currentItem = _currentItem, currentIndex = _currentIndex;
@synthesize cancelled = _cancelled;
@synthesize items = _items, URL = _URL, workQueue = _workQueue;

- (instancetype)initWithURL:(NSURL *)queueURL {
    self = [super init];
    if (self) {
        _workQueue = dispatch_queue_create("org.subler.WorkQueue", NULL);
        _URL = [queueURL copy];

        if ([[NSFileManager defaultManager] fileExistsAtPath:[queueURL path]]) {
            @try {
                _items = [[NSKeyedUnarchiver unarchiveObjectWithFile:[queueURL path]] retain];
            } @catch (NSException *exception) {
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
    return [NSKeyedArchiver archiveRootObject:self.items toFile:[self.URL path]];
}


- (SBQueueItem *)firstItemInQueue {
    __block SBQueueItem *firstItem = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        for (SBQueueItem *item in self.items) {
            if ((item.status != SBQueueItemStatusCompleted) && (item.status != SBQueueItemStatusFailed)) {
                firstItem = [item retain];
                firstItem.status = SBQueueItemStatusWorking;
                break;
            }
        }
    });
    return [firstItem autorelease];
}

#pragma mark - item management

- (void)addItem:(SBQueueItem *)item {
    [self.items addObject:item];
}

- (NSUInteger)count {
    return [self.items count];
}

- (NSUInteger)readyCount {
    NSUInteger count = 0;
    for (SBQueueItem *item in self.items)
        if ([item status] == SBQueueItemStatusReady)
            count++;
    return count;
}

- (SBQueueItem *)itemAtIndex:(NSUInteger)index {
    return [self.items objectAtIndex:index];
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
        if ([item status] == SBQueueItemStatusCompleted)
            [indexes addIndex:[self.items indexOfObject:item]];

    [self.items removeObjectsAtIndexes:indexes];

    return [indexes autorelease];
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

                self.currentIndex = [self.items indexOfObject:self.currentItem];
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
                } else {
                    self.currentItem.status = SBQueueItemStatusFailed;
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
        [self handleSBStatusCompleted];

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
        description = NSLocalizedString(@"Working", @"");
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
- (void)handleSBStatusCompleted {
    self.status = SBQueueStatusCompleted;
    [[NSNotificationCenter defaultCenter] postNotificationName:SBQueueCompletedNotification object:self];
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

- (void)dealloc {
    dispatch_release(_workQueue);

    [_items release];
    [_URL release];

    [super dealloc];
}

@end
