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
    NSMutableArray *_presets;
}

+ (SBPresetManager *)sharedManager;

- (void)newSetFromExistingMetadata:(MP42Metadata *)set;
- (BOOL)savePresets;

- (BOOL)removePresetAtIndex:(NSUInteger)index;

@property(readonly) NSArray *presets;

@end
