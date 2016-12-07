//
//  SBPresetManager.m
//  Subler
//
//  Created by Damiano Galassi on 02/01/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SBPresetManager.h"
#import <MP42Foundation/MP42Metadata.h>

/// Notification sent to update presets lists.
NSString *SBPresetManagerUpdatedNotification = @"SBPresetManagerUpdatedNotification";

@interface SBPresetManager ()
{
    NSMutableArray<MP42Metadata *> *_presets;
}

- (BOOL)removePresetWithName:(NSString*)name;

@end

@implementation SBPresetManager

@synthesize presets = _presets;

+ (SBPresetManager *)sharedManager
{
    static dispatch_once_t pred;
    static SBPresetManager *sharedPresetManager = nil;

    dispatch_once(&pred, ^{ sharedPresetManager = [[self alloc] init]; });
    return sharedPresetManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _presets = [[NSMutableArray alloc] init];

        [self loadPresets];
    }

    return self;
}

- (void)updateNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPresetManagerUpdatedNotification object:self];    
}

- (void)newSetFromExistingMetadata:(MP42Metadata *)set
{
    MP42Metadata *newSet = [set copy];
    [_presets addObject:newSet];

    [self savePresets];
    [self updateNotification];
}

- (NSURL *)appSupportURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [[fileManager URLsForDirectory:NSApplicationSupportDirectory
                                inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"Subler"];
}

- (BOOL)loadPresets
{
    NSURL *appSupportURL = [self appSupportURL];

    if (!appSupportURL) {
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *directoryEnumerator =
    [fileManager enumeratorAtURL:appSupportURL
           includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                              options:NSDirectoryEnumerationSkipsHiddenFiles
                         errorHandler:nil];

    for (NSURL *fileURL in directoryEnumerator) {
        NSNumber *isDirectory = nil;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if ([isDirectory boolValue] == NO && [fileURL.pathExtension isEqualToString:@"sbpreset"]) {
            @try {
                NSData *queue = [NSData dataWithContentsOfURL:fileURL];
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:queue];
                unarchiver.requiresSecureCoding = YES;
                MP42Metadata *newPreset = [unarchiver decodeObjectOfClass:[MP42Metadata class] forKey:NSKeyedArchiveRootObjectKey];
                [unarchiver finishDecoding];

                if (newPreset) {
                    [_presets addObject:newPreset];
                }
            }
            @catch (NSException *exception) {
                continue;
            }
        }
    }

    return _presets.count > 0;
}

- (BOOL)savePresets
{
    NSURL *appSupportURL = [self appSupportURL];

    if (!appSupportURL) {
        return NO;
    }

    BOOL noErr = YES;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (![fileManager fileExistsAtPath:appSupportURL.path]) {
        [fileManager createDirectoryAtURL:appSupportURL withIntermediateDirectories:noErr attributes:nil error:NULL];
    }

    for (MP42Metadata *preset in _presets) {
        NSURL *presetURL = [appSupportURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sbpreset", preset.presetName]];

        NSMutableData *data = [[NSMutableData alloc] init];

        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
        archiver.requiresSecureCoding = YES;
        [archiver encodeObject:preset forKey:NSKeyedArchiveRootObjectKey];
        [archiver finishEncoding];

        noErr = [data writeToURL:presetURL atomically:YES];
    }
    return noErr;
}

- (MP42Metadata *)setWithName:(NSString *)name {
    for (MP42Metadata *set in _presets) {
        if ([set.presetName isEqualToString:name]) {
            return set;
        }
    }
    return nil;
}

- (BOOL)removePresetAtIndex:(NSUInteger)index
{
    NSString *name = _presets[index].presetName;
    [_presets removeObjectAtIndex:index];

    [self updateNotification];

    return [self removePresetWithName:name];
}

- (BOOL)removePresetWithName:(NSString *)name
{
    BOOL err = NO;
    NSURL *appSupportURL = [self appSupportURL];

    if (!appSupportURL) {
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    err = [fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@.sbpreset", appSupportURL.path, name]
                                  error:NULL];

    return err;
}

@end
