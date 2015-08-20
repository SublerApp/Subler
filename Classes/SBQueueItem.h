//
//  SBQueueItem.h
//  Subler
//
//  Created by Damiano Galassi on 16/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBQueueAction.h"

@class MP42File;

NS_ASSUME_NONNULL_BEGIN

typedef enum SBQueueItemStatus : NSInteger {
    SBQueueItemStatusUnknown = 0,
    SBQueueItemStatusReady,
    SBQueueItemStatusEditing,
    SBQueueItemStatusWorking,
    SBQueueItemStatusCompleted,
    SBQueueItemStatusFailed,
    SBQueueItemStatusCancelled,
} SBQueueItemStatus;

@interface SBQueueItem : NSObject <NSCoding> {
@private
    MP42File *_mp4File;
    NSURL    *_fileURL;
    NSURL    *_destURL;

    NSDictionary<NSString *, id> *_attributes;
    NSMutableArray<id<SBQueueActionProtocol>> *_actions;

    BOOL _cancelled;

    id _delegate;

    SBQueueItemStatus _status;
    NSString *_localizedWorkingDescription;
}

@property (nonatomic, readwrite) SBQueueItemStatus status;
@property (nonatomic, readonly, nullable) NSString *localizedWorkingDescription;

@property (nonatomic, readonly, nullable) MP42File *mp4File;

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, copy) NSURL *destURL;

@property (nonatomic, readonly) NSArray<id<SBQueueActionProtocol>> *actions;
@property (nonatomic, readonly) NSDictionary<NSString *, id> *attributes;

@property (nonatomic, assign, nullable) id delegate;

+ (instancetype)itemWithURL:(NSURL *)URL;

+ (instancetype)itemWithMP4:(MP42File *)MP4;
+ (instancetype)itemWithMP4:(MP42File *)MP4 destinationURL:(NSURL *)destURL attributes:(NSDictionary *)dict;

- (void)addAction:(id<SBQueueActionProtocol>)action;
- (void)removeAction:(id<SBQueueActionProtocol>)action;

- (BOOL)prepare:(NSError **)outError;
- (BOOL)processWithOptions:(BOOL)optimize error:(NSError **)outError;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
