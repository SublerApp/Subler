//
//  SBPresetManager.h
//  Subler
//
//  Created by Damiano Galassi on 02/01/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MP42Metadata;

extern NSString *SBPresetManagerUpdatedNotification;

@interface SBPresetManager : NSObject {
@private
    NSMutableArray *_presets;
}

+ (SBPresetManager *)sharedManager;

- (void)newSetFromExistingMetadata:(MP42Metadata *)set;
- (BOOL)savePresets;

- (MP42Metadata *)setWithName:(NSString *)name;
- (BOOL)removePresetAtIndex:(NSUInteger)index;

@property(readonly) NSArray *presets;

@end
