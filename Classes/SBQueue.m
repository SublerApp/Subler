//
//  SBQueue.m
//  Subler
//
//  Created by Damiano Galassi on 27/02/14.
//
//

#import "SBQueue.h"
#import "SBQueueItem.h"

#import "MetadataImporter.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Utilities.h>

static NSString *fileType = @"mp4";

NSString *SBQueueWorkingNotification = @"SBQueueWorkingNotification";
NSString *SBQueueCompletedNotification = @"SBQueueCompletedNotification";
NSString *SBQueueFailedNotification = @"SBQueueFailedNotification";
NSString *SBQueueCancelledNotification = @"SBQueueCancelledNotification";

@interface SBQueue () <MP42FileDelegate>

@property (atomic) SBQueueStatus status;

@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, retain) NSMutableArray *items;

@property (nonatomic) dispatch_queue_t queue;

@end

@implementation SBQueue

@synthesize status = _status, destination = _destination;
@synthesize optimize = _optimize;
@synthesize items = _items, URL = _URL, queue = _queue;

- (instancetype)initWithURL:(NSURL *)queueURL {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("org.subler.Queue", NULL);
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


- (SBQueueItem *)firstItemInQueue
{
    for (SBQueueItem *item in self.items)
        if ((item.status != SBQueueItemStatusCompleted) && (item.status != SBQueueItemStatusFailed))
            return item;

    return nil;
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
        if ([item status] != SBQueueItemStatusCompleted)
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
    _io_success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep,
                                                      kIOPMAssertionLevelOn, reasonForActivity, &_assertionID);
}

- (void)enableSleep {
    if (_io_success == kIOReturnSuccess) {
        IOPMAssertionRelease(_assertionID);
    }
}

- (void)start {
    if (self.status == SBQueueStatusWorking) {
        return;
    } else {
        self.status = SBQueueStatusWorking;
    }

    // Enable sleep assertion
    [self disableSleep];

    dispatch_async(self.queue, ^{
        NSError *outError = nil;
        BOOL noErr = NO;

        for (;;) {
            @autoreleasepool {
                __block SBQueueItem *item = nil;

                // Get the first item available in the queue
                dispatch_sync(dispatch_get_main_queue(), ^{
                    item = [[self firstItemInQueue] retain];
                    item.status = SBQueueItemStatusWorking;
                });

                if (item == nil) {
                    break;
                }

                [self handleSBStatusWorking];
                noErr = [self processItem:item error:&outError];

                // Check results
                if (_cancelled) {
                    item.status = SBQueueItemStatusCancelled;
                    [item release];
                    [self handleSBStatusCancelled];
                    break;
                } else if (noErr) {
                    if (self.optimize) {
                        noErr = [_currentMP4 optimize];
                    }
                }

                if (noErr) {
                    item.status = SBQueueItemStatusCompleted;
                } else {
                    item.status = SBQueueItemStatusFailed;
                    if (outError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [NSApp presentError:outError];
                        });
                    }
                }

                // Save the queue
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self saveQueueToDisk];
                });

                [item release];
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
- (BOOL)processItem:(SBQueueItem *)item error:(NSError **)outError {
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] boolValue])
        [attributes setObject:@YES forKey:MP42GenerateChaptersPreviewTrack];

#ifdef SB_SANDBOX
    if([destination respondsToSelector:@selector(startAccessingSecurityScopedResource)])
        [destination startAccessingSecurityScopedResource];
#endif

    BOOL noErr = YES;

    _currentMP4 = [item mp4File];
    [_currentMP4 setDelegate:self];

    // Set the destination url
    if (![item destURL]) {
        if (!_currentMP4 && self.destination /*&& customDestination*/) {
            item.destURL = [[[self.destination URLByAppendingPathComponent:[item.URL lastPathComponent]] URLByDeletingPathExtension] URLByAppendingPathExtension:fileType];
        } else {
            item.destURL = [[item.URL URLByDeletingPathExtension] URLByAppendingPathExtension:fileType];
        }
    }

    // The file has been added directly to the queue
    if (!_currentMP4 && item.URL) {
        [item prepareItem:outError];
        _currentMP4 = item.mp4File;
    }

    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[_currentMP4.URL path] error:NULL];
    NSNumber *freeSpace = [dict objectForKey:NSFileSystemFreeSize];
    if (freeSpace && [_currentMP4 dataSize] > [freeSpace longLongValue]) {
        NSLog(@"Not enough disk space");
    }

    // We have an existing mp4 file, update it
    if (!_cancelled) {
        if ([_currentMP4 hasFileRepresentation])
            noErr = [_currentMP4 updateMP4FileWithAttributes:attributes error:outError];
        // Write the new file to disk
        else if (_currentMP4 && item.destURL) {
            [attributes addEntriesFromDictionary:[item attributes]];
            noErr = [_currentMP4 writeToUrl:[item destURL]
                               withAttributes:attributes
                                        error:outError];
        }
    }

#ifdef SB_SANDBOX
    if([destination respondsToSelector:@selector(stopAccessingSecurityScopedResource)])
        [destination stopAccessingSecurityScopedResource];
#endif

    [attributes release];
    return noErr;
}

- (void)stop {
    _cancelled = YES;
}

- (void)progressStatus:(CGFloat)progress {
    NSLog(@"%f", progress);
}

/**
 * Processes SBQueueStatusWorking state information. Current implementation just
 * sends SBQueueWorkingNotification.
 */
- (void)handleSBStatusWorking {
    [[NSNotificationCenter defaultCenter] postNotificationName:SBQueueWorkingNotification object:self];
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
- (void)handleSBStatusFailed {
    self.status = SBQueueStatusFailed;
    [[NSNotificationCenter defaultCenter] postNotificationName:SBQueueFailedNotification object:self];
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
    dispatch_release(_queue);

    [_items release];
    [_URL release];

    [super dealloc];
}

@end
