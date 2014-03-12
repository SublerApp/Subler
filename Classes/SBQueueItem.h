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

typedef enum SBQueueItemStatus : NSInteger {
    SBQueueItemtatusUnknown = 0,
    SBQueueItemStatusReady,
    SBQueueItemStatusEditing,
    SBQueueItemStatusWorking,
    SBQueueItemStatusCompleted,
    SBQueueItemStatusFailed,
    SBQueueItemStatusCancelled,
} SBQueueItemStatus;

@interface SBQueueItem : NSObject <NSCoding> {
    MP42File *_mp4File;
    NSURL    *_fileURL;
    NSURL    *_destURL;
    NSDictionary   *_attributes;
    NSMutableArray *_actions;

    SBQueueItemStatus _status;
}

@property (nonatomic, readonly) MP42File *mp4File;
@property (nonatomic, readonly) NSDictionary *attributes;
@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, copy, readwrite) NSURL *destURL;

@property (nonatomic, readwrite) SBQueueItemStatus status;

- (instancetype)initWithURL:(NSURL *)URL;
+ (instancetype)itemWithURL:(NSURL *)URL;

- (instancetype)initWithMP4:(MP42File *)MP4;
- (instancetype)initWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict;

+ (instancetype)itemWithMP4:(MP42File *)MP4;
+ (instancetype)itemWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict;

- (void)addAction:(id<SBQueueActionProtocol>)action;

- (BOOL)prepareItem:(NSError **)outError;

@end
