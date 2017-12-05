//
//  SBQueueItem.h
//  Subler
//
//  Created by Damiano Galassi on 16/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42File;
@class SBQueueItem;

/**
 *  SBQueue actions protocol, actions can be run by
 *  the queue's items.
 */
@protocol SBQueueActionProtocol <NSObject, NSSecureCoding>
- (void)runAction:(SBQueueItem *)item;
@property (nonatomic, readonly) NSString *localizedDescription;
@end


typedef NS_ENUM(NSUInteger, SBQueueItemStatus) {
    SBQueueItemStatusUnknown = 0,
    SBQueueItemStatusReady,
    SBQueueItemStatusEditing,
    SBQueueItemStatusWorking,
    SBQueueItemStatusCompleted,
    SBQueueItemStatusFailed,
    SBQueueItemStatusCancelled,
};

@interface SBQueueItem : NSObject <NSSecureCoding>

@property (nonatomic, readwrite) SBQueueItemStatus status;
@property (nonatomic, readonly, nullable) NSString *localizedWorkingDescription;

@property (nonatomic, readonly, nullable) MP42File *mp4File;

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, copy) NSURL *destURL;

@property (nonatomic, readonly) NSArray<id<SBQueueActionProtocol>> *actions;
@property (nonatomic, readonly) NSDictionary<NSString *, id> *attributes;

@property (nonatomic, weak, nullable) id delegate;

+ (instancetype)itemWithURL:(NSURL *)URL;

+ (instancetype)itemWithMP4:(MP42File *)MP4;
+ (instancetype)itemWithMP4:(MP42File *)MP4 destinationURL:(NSURL *)destURL attributes:(NSDictionary *)dict;

- (void)addAction:(id<SBQueueActionProtocol>)action;
- (void)removeAction:(id<SBQueueActionProtocol>)action;

- (BOOL)prepare:(NSError * __autoreleasing *)outError;
- (BOOL)processWithOptions:(BOOL)optimize error:(NSError * __autoreleasing *)outError;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
