//
//  SBQueue.m
//  Subler
//
//  Created by Damiano Galassi on 27/02/14.
//
//

#import "SBQueue.h"

#import "MetadataImporter.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Utilities.h>

NSString *SBQueueWorkingNotification = @"SBQueueWorkingNotification";
NSString *SBQueueCompletedNotification = @"SBQueueCompletedNotification";
NSString *SBQueueFailedNotification = @"SBQueueFailedNotification";
NSString *SBQueueCancelledNotification = @"SBQueueCancelledNotification";

@interface SBQueue () <MP42FileDelegate>

@property (atomic) SBQueueStatus status;

@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, retain) NSMutableArray *items;

@property (atomic, retain) SBQueueItem *currentItem;
@property (atomic) NSUInteger currentIndex;
@property (atomic) BOOL cancelled;

@property (nonatomic) dispatch_queue_t workQueue;
@property (nonatomic) dispatch_queue_t itemsQueue;

@end

@implementation SBQueue

@synthesize status = _status;
@synthesize optimize = _optimize;
@synthesize currentItem = _currentItem, currentIndex = _currentIndex;
@synthesize cancelled = _cancelled;
@synthesize items = _items, itemsQueue = _itemsQueue, URL = _URL, workQueue = _workQueue;

- (instancetype)initWithURL:(NSURL *)queueURL {
    self = [super init];
    if (self) {
        _workQueue = dispatch_queue_create("org.subler.WorkQueue", NULL);
        _itemsQueue = dispatch_queue_create("org.subler.ItemsQueue", NULL);
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
    __block BOOL noErr = YES;
    dispatch_sync(self.itemsQueue, ^{
        noErr = [NSKeyedArchiver archiveRootObject:self.items toFile:[self.URL path]];
    });
    return noErr;
}


- (SBQueueItem *)firstItemInQueue
{
    __block SBQueueItem *firstItem = nil;
    dispatch_sync(self.itemsQueue, ^{
        for (SBQueueItem *item in self.items) {
            if ((item.status != SBQueueItemStatusCompleted) && (item.status != SBQueueItemStatusFailed)) {
                firstItem = [item retain];
                break;
            }
        }
    });
    return [firstItem autorelease];
}

#pragma mark - item management

- (void)addItem:(SBQueueItem *)item {
    dispatch_sync(self.itemsQueue, ^{
        [self.items addObject:item];
    });
}

- (NSUInteger)count {
    __block NSUInteger count = 0;
    dispatch_sync(self.itemsQueue, ^{
        count =  [self.items count];
    });
    return count;
}

- (NSUInteger)readyCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.itemsQueue, ^{
        for (SBQueueItem *item in self.items)
            if ([item status] != SBQueueItemStatusCompleted)
                count++;
    });
    return count;
}

- (SBQueueItem *)itemAtIndex:(NSUInteger)index {
    __block SBQueueItem *item = nil;
    dispatch_sync(self.itemsQueue, ^{
        item = [self.items objectAtIndex:index];
    });
    return item;
}

- (NSArray *)itemsAtIndexes:(NSIndexSet *)indexes {
    __block NSArray *items = nil;
    dispatch_sync(self.itemsQueue, ^{
        items =  [self.items objectsAtIndexes:indexes];
    });
    return items;
}

- (NSUInteger)indexOfItem:(SBQueueItem *)item {
    __block NSUInteger index = NSNotFound;
    dispatch_sync(self.itemsQueue, ^{
        index = [self.items indexOfObject:item];
    });
    return index;
}

- (NSIndexSet *)indexesOfItemsWithStatus:(SBQueueItemStatus)status {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    dispatch_sync(self.itemsQueue, ^{
        [self.items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (((SBQueueItem *)obj).status == status) {
                [indexes addIndex:idx];
            }
        }];
    });
    return indexes;
}

- (void)insertItem:(SBQueueItem *)anItem atIndex:(NSUInteger)index {
    dispatch_sync(self.itemsQueue, ^{
        [self.items insertObject:anItem atIndex:index];
    });
}

- (void)removeItemsAtIndexes:(NSIndexSet *)indexes {
    dispatch_sync(self.itemsQueue, ^{
        [self.items removeObjectsAtIndexes:indexes];
    });
}

- (void)removeItem:(SBQueueItem *)item {
    dispatch_sync(self.itemsQueue, ^{
        [self.items removeObject:item];
    });
}

- (NSIndexSet *)removeCompletedItems {
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];

    dispatch_sync(self.itemsQueue, ^{
        for (SBQueueItem *item in self.items)
            if ([item status] == SBQueueItemStatusCompleted)
                [indexes addIndex:[self.items indexOfObject:item]];

        [self.items removeObjectsAtIndexes:indexes];
    });

    return [indexes autorelease];
}

#pragma mark - Queue control

- (void)disableSleep {
    CFStringRef reasonForActivity= CFSTR("Subler Queue Started");
    _io_success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep,
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
        NSError *outError = nil;
        BOOL noErr = NO;

        for (;;) {
            @autoreleasepool {
                // Save the queue
                [self saveQueueToDisk];

                // Get the first item available in the queue
                self.currentItem = [self firstItemInQueue];

                if (!self.currentItem) {
                    break;
                }

                self.currentIndex = [self.items indexOfObject:self.currentItem];
                self.currentItem.status = SBQueueItemStatusWorking;

                [self handleSBStatusWorking:self.currentIndex];
                noErr = [self processItem:self.currentItem optimize:self.optimize error:&outError];

                // Check results
                if (self.cancelled) {
                    self.currentItem.status = SBQueueItemStatusCancelled;
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
    });
}

/**
 * Processes a SBQueueItem.
 */
- (BOOL)processItem:(SBQueueItem *)item optimize:(BOOL)optimize error:(NSError **)outError {
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] boolValue])
        [attributes setObject:@YES forKey:MP42GenerateChaptersPreviewTrack];

#ifdef SB_SANDBOX
    if([destination respondsToSelector:@selector(startAccessingSecurityScopedResource)])
        [destination startAccessingSecurityScopedResource];
#endif

    BOOL noErr = YES;
    MP42File *file = nil;

    // The file has been added directly to the queue
    if (!item.mp4File && item.URL) {
        [item prepareItem:outError];
        file = item.mp4File;
    }

    file.delegate = self;

    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[file.URL path] error:NULL];
    NSNumber *freeSpace = [dict objectForKey:NSFileSystemFreeSize];
    if (freeSpace && [file dataSize] > [freeSpace longLongValue]) {
        NSLog(@"Not enough disk space");
        [self stop];
    }

    if (!self.cancelled) {
        if ([file hasFileRepresentation]) {
            // We have an existing mp4 file, update it
            noErr = [file updateMP4FileWithAttributes:attributes error:outError];
        } else if (file && item.destURL) {
            // Write the new file to disk
            [attributes addEntriesFromDictionary:item.attributes];
            noErr = [file writeToUrl:item.destURL
                                 withAttributes:attributes
                                          error:outError];
        }
    }

    if (noErr && optimize) {
        [file optimize];
    }

#ifdef SB_SANDBOX
    if([destination respondsToSelector:@selector(stopAccessingSecurityScopedResource)])
        [destination stopAccessingSecurityScopedResource];
#endif

    [attributes release];

    return noErr;
}

/**
 * Stops the queue and abort the current work.
 */
- (void)stop {
    self.cancelled = YES;
    [self.currentItem.mp4File cancel];
}

- (void)progressStatus:(CGFloat)progress {
    [self handleSBStatusWorking:progress];
}

/**
 * Processes SBQueueStatusWorking state information. Current implementation just
 * sends SBQueueWorkingNotification.
 */
- (void)handleSBStatusWorking:(CGFloat)progress {
    NSString *info = [NSString stringWithFormat:@"Processing file %ld of %lu.",(long)self.currentIndex + 1, (unsigned long)[self.items count]];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBQueueWorkingNotification object:self userInfo:@{@"ProgressString": info,
                                                                                                                 @"Progress": @(progress)}];
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
    dispatch_release(_itemsQueue);

    [_items release];
    [_URL release];

    [super dealloc];
}

@end
