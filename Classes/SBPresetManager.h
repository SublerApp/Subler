//
//  SBPresetManager.h
//  Subler
//
//  Created by Damiano Galassi on 02/01/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42Metadata;

extern NSString *SBPresetManagerUpdatedNotification;

@interface SBPresetManager : NSObject {
@private
    NSMutableArray<MP42Metadata *> *_presets;
}

+ (SBPresetManager *)sharedManager;

- (void)newSetFromExistingMetadata:(MP42Metadata *)set;
- (BOOL)savePresets;

- (nullable MP42Metadata *)setWithName:(NSString *)name;
- (BOOL)removePresetAtIndex:(NSUInteger)index;

@property(atomic, readonly) NSArray<MP42Metadata *> *presets;

@end

NS_ASSUME_NONNULL_END
