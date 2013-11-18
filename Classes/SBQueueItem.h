//
//  SBQueueItem.h
//  Subler
//
//  Created by Damiano Galassi on 16/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MP42File;

typedef enum SBQueueItemStatus : NSInteger {
    SBQueueItemtatusUnknown = 0,
    SBQueueItemStatusReady,
    SBQueueItemStatusWorking,
    SBQueueItemStatusCompleted,
    SBQueueItemStatusFailed,
    SBQueueItemStatusCancelled,
} SBQueueItemStatus;

@interface SBQueueItem : NSObject <NSCoding> {
    MP42File *mp4File;
    NSURL   *fileURL;
    NSURL   *destURL;
    NSDictionary *attributes;

    SBQueueItemStatus status;
    BOOL humanEdited;
}

@property (atomic, readonly) MP42File *mp4File;
@property (atomic, readonly) NSDictionary *attributes;
@property (atomic, readonly) NSURL *URL;
@property (atomic, retain, readwrite) NSURL *destURL;

@property (atomic, readwrite) SBQueueItemStatus status;

- (instancetype)initWithURL:(NSURL *)URL;
+ (instancetype)itemWithURL:(NSURL *)URL;

- (instancetype)initWithMP4:(MP42File *)MP4;
- (instancetype)initWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict;

+ (instancetype)itemWithMP4:(MP42File *)MP4;
+ (instancetype)itemWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict;

@end
