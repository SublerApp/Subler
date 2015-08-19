//
//  SBQueue.h
//  Subler
//
//  Created by Damiano Galassi on 27/02/14.
//
//

#import <Foundation/Foundation.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

#import "SBQueueItem.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SBQueueStatus) {
    SBQueueStatusUnknown = 0,
    SBQueueStatusWorking,
    SBQueueStatusCompleted,
    SBQueueStatusFailed,
    SBQueueStatusCancelled,
};

extern NSString *SBQueueWorkingNotification;
extern NSString *SBQueueCompletedNotification;
extern NSString *SBQueueFailedNotification;
extern NSString *SBQueueCancelledNotification;

@interface SBQueue : NSObject {
    @private
    dispatch_queue_t   _workQueue;
    SBQueueStatus      _status;

    SBQueueItem        *_currentItem;
    NSUInteger          _currentIndex;
    NSMutableArray<SBQueueItem *> *_items;
    NSURL              *_URL;

    IOPMAssertionID _assertionID;
    IOReturn        _io_success;
    BOOL            _cancelled;

    BOOL _optimize;
}

@property (atomic, readonly) SBQueueStatus status;
@property (atomic) BOOL optimize;

- (instancetype)initWithURL:(NSURL *)queueURL;

- (void)start;
- (void)stop;

- (void)addItem:(SBQueueItem *)item;

- (NSUInteger)count;
- (NSUInteger)readyCount;

- (SBQueueItem *)itemAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfItem:(SBQueueItem *)item;
- (NSIndexSet *)indexesOfItemsWithStatus:(SBQueueItemStatus)status;
- (NSArray<SBQueueItem *> *)itemsAtIndexes:(NSIndexSet *)indexes;

- (void)insertItem:(SBQueueItem *)anItem atIndex:(NSUInteger)index;

- (void)removeItemsAtIndexes:(NSIndexSet *)indexes;
- (void)removeItem:(SBQueueItem *)item;

- (NSIndexSet *)removeCompletedItems;

- (BOOL)saveQueueToDisk;

@end

NS_ASSUME_NONNULL_END

